import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/month_filter_pill.dart';
import '../../domain/entities/compte_courant.dart';
import '../providers/tresorerie_providers.dart';

/// Formulaire d'arrêté de compte : choisir la période, prévisualiser le décompte
/// (fonds − créances par antériorité = net), puis confirmer la restitution.
class ArreteFormPage extends ConsumerStatefulWidget {
  final String perimetre; // CHAUFFEUR | VEHICULE
  final int perimetreId;
  final String libelle;

  const ArreteFormPage({
    super.key,
    required this.perimetre,
    required this.perimetreId,
    required this.libelle,
  });

  @override
  ConsumerState<ArreteFormPage> createState() => _ArreteFormPageState();
}

class _ArreteFormPageState extends ConsumerState<ArreteFormPage> {
  late int _annee;
  late int _mois;
  String _mode = 'ESPECES';

  ArreteCompte? _apercu;
  bool _loading = true;
  bool _submitting = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _annee = now.year;
    _mois = now.month;
    _chargerApercu();
  }

  DateTime get _debut => DateTime(_annee, _mois, 1);
  DateTime get _fin => DateTime(_annee, _mois + 1, 0);

  Future<void> _chargerApercu() async {
    setState(() {
      _loading = true;
      _erreur = null;
    });
    try {
      final apercu = await ref.read(tresorerieDatasourceProvider).getApercuArrete(
            perimetre: widget.perimetre,
            perimetreId: widget.perimetreId,
            debut: _debut,
            fin: _fin,
          );
      if (mounted) setState(() => _apercu = apercu);
    } catch (e) {
      if (mounted) setState(() => _erreur = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmer() async {
    setState(() => _submitting = true);
    try {
      await ref.read(tresorerieDatasourceProvider).arreter(
            perimetre: widget.perimetre,
            perimetreId: widget.perimetreId,
            periodeDebut: _debut,
            periodeFin: _fin,
            modePaiement: _mode,
          );
      // Rafraîchit créances, trésorerie, historique et comptes courants.
      ref.invalidate(arretesProvider);
      ref.invalidate(balanceAgeeProvider);
      ref.invalidate(balanceAgeeVehiculeProvider);
      ref.invalidate(tresorerieSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Arrêté enregistré')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Arrêté refusé : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apercu = _apercu;
    final rien = apercu == null || apercu.reglements.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text('Arrêté — ${widget.libelle}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          const Text('Période à restituer',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label)),
          const SizedBox(height: 6),
          MonthFilterPill(
            mois: _mois,
            annee: _annee,
            onChanged: (m, a) {
              setState(() {
                _mois = m;
                _annee = a;
              });
              _chargerApercu();
            },
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()))
          else if (_erreur != null)
            _MessageCard(
                'Impossible de calculer le décompte : $_erreur',
                Colors.red.shade900, const Color(0xFFFDECEA))
          else if (rien)
            const _MessageCard(
                'Aucune cotisation ni créance sur cette période.',
                AppColors.label, AppColors.headerButton)
          else ...[
            _SyntheseCard(apercu: apercu),
            const SizedBox(height: 12),
            for (final r in apercu.reglements) _ReglementCard(reglement: r),
            const SizedBox(height: 16),
            if (apercu.totalRestitue > 0) ...[
              const Text('Mode de versement',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ESPECES', label: Text('Espèces')),
                  ButtonSegment(value: 'MOBILE_MONEY', label: Text('Mobile Money')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: rien
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _submitting || _loading ? null : _confirmer,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: Text(apercu.totalRestitue > 0
                    ? 'Restituer ${CurrencyFormatter.format(apercu.totalRestitue)}'
                    : 'Compenser (aucun versement)'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ),
    );
  }
}

class _SyntheseCard extends StatelessWidget {
  final ArreteCompte apercu;
  const _SyntheseCard({required this.apercu});

  @override
  Widget build(BuildContext context) {
    final fonds =
        apercu.reglements.fold<double>(0, (s, r) => s + r.totalCotisations);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.8)),
      child: Column(
        children: [
          _ligne('Fonds de cotisation', fonds, AppColors.dark),
          const Divider(height: 18),
          _ligne('− Créances compensées', apercu.totalCompense,
              Colors.orange.shade900),
          if (apercu.totalReliquat > 0)
            _ligne('Reliquat reporté', apercu.totalReliquat,
                Colors.red.shade900),
          const Divider(height: 18),
          _ligne('= Net à restituer', apercu.totalRestitue,
              Colors.green.shade800,
              gras: true),
        ],
      ),
    );
  }

  Widget _ligne(String label, double montant, Color couleur, {bool gras = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: gras ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.dark)),
          Text(CurrencyFormatter.format(montant),
              style: TextStyle(
                  fontSize: gras ? 15 : 13,
                  fontWeight: gras ? FontWeight.w700 : FontWeight.w600,
                  color: couleur)),
        ],
      ),
    );
  }
}

class _ReglementCard extends StatelessWidget {
  final ReglementArrete reglement;
  const _ReglementCard({required this.reglement});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reglement.chauffeurNom ?? 'Chauffeur #${reglement.chauffeurId}',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark)),
                const SizedBox(height: 2),
                Text(
                    'Cotisations ${CurrencyFormatter.format(reglement.totalCotisations)}'
                    ' · compensé ${CurrencyFormatter.format(reglement.totalCreancesCompensees)}'
                    '${reglement.reliquatReporte > 0 ? ' · reliquat ${CurrencyFormatter.format(reglement.reliquatReporte)}' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.label)),
              ],
            ),
          ),
          Text(CurrencyFormatter.format(reglement.montantNet),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: reglement.aRestitution
                      ? Colors.green.shade800
                      : AppColors.hint)),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  final Color fg;
  final Color bg;
  const _MessageCard(this.message, this.fg, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(message, style: TextStyle(fontSize: 13, color: fg)),
    );
  }
}
