import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/month_filter_pill.dart';
import '../../domain/entities/compte_courant.dart';
import '../providers/tresorerie_providers.dart';

/// Formulaire d'arrêté de compte : choisir la période, **sélectionner les lignes**
/// à restituer/compenser (restitution partielle), prévisualiser le décompte
/// (fonds − créances = net), puis confirmer. Toutes les lignes sont cochées par
/// défaut → l'arrêté total reste le comportement d'un simple « Restituer ».
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

  /// Cotisations retenues (documentId de la ligne de cotisation).
  final Set<int> _cotisationsChoisies = {};

  /// Créances retenues, clé « DOCUMENT:documentId ».
  final Set<String> _creancesChoisies = {};

  static String _cleCreance(LigneArrete l) => '${l.document}:${l.documentId}';

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
      if (mounted) {
        setState(() {
          _apercu = apercu;
          _toutSelectionner(apercu);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toutSelectionner(ArreteCompte apercu) {
    _cotisationsChoisies
      ..clear()
      ..addAll(apercu.lignes.where((l) => l.estCredit).map((l) => l.documentId));
    _creancesChoisies
      ..clear()
      ..addAll(apercu.lignes.where((l) => !l.estCredit).map(_cleCreance));
  }

  void _toutCocher() {
    final apercu = _apercu;
    if (apercu != null) setState(() => _toutSelectionner(apercu));
  }

  void _toutDecocher() => setState(() {
        _cotisationsChoisies.clear();
        _creancesChoisies.clear();
      });

  // ── Décompte local (le serveur reste l'autorité) ────────────────────────────

  /// Groupe les lignes de l'aperçu par bénéficiaire chauffeur.
  List<_GroupeBeneficiaire> get _groupes {
    final apercu = _apercu;
    if (apercu == null) return const [];
    final noms = {for (final r in apercu.reglements) r.chauffeurId: r.chauffeurNom};
    final parChauffeur = <int, _GroupeBeneficiaire>{};
    for (final l in apercu.lignes) {
      final id = l.chauffeurId ?? -1;
      final g = parChauffeur.putIfAbsent(
          id, () => _GroupeBeneficiaire(id, noms[id] ?? 'Chauffeur #$id'));
      (l.estCredit ? g.cotisations : g.creances).add(l);
    }
    return parChauffeur.values.toList();
  }

  bool _cotChoisie(LigneArrete l) => _cotisationsChoisies.contains(l.documentId);
  bool _creChoisie(LigneArrete l) => _creancesChoisies.contains(_cleCreance(l));

  double _fondsGroupe(_GroupeBeneficiaire g) =>
      g.cotisations.where(_cotChoisie).fold(0.0, (s, l) => s + l.montant);

  double _creancesGroupe(_GroupeBeneficiaire g) =>
      g.creances.where(_creChoisie).fold(0.0, (s, l) => s + l.montant);

  /// Compensé = min(fonds, créances) ; le fonds éteint les créances (par antériorité côté serveur).
  double _compenseGroupe(_GroupeBeneficiaire g) =>
      math.min(_fondsGroupe(g), _creancesGroupe(g));

  double _netGroupe(_GroupeBeneficiaire g) =>
      _fondsGroupe(g) - _compenseGroupe(g);

  double get _totalFonds =>
      _groupes.fold(0.0, (s, g) => s + _fondsGroupe(g));
  double get _totalCompense =>
      _groupes.fold(0.0, (s, g) => s + _compenseGroupe(g));
  double get _totalNet => _groupes.fold(0.0, (s, g) => s + _netGroupe(g));

  bool get _peutValider => _cotisationsChoisies.isNotEmpty;

  void basculeCotisation(int documentId, bool? coche) => setState(() {
        if (coche == true) {
          _cotisationsChoisies.add(documentId);
        } else {
          _cotisationsChoisies.remove(documentId);
        }
      });

  void basculeCreance(LigneArrete l, bool? coche) => setState(() {
        final cle = _cleCreance(l);
        if (coche == true) {
          _creancesChoisies.add(cle);
        } else {
          _creancesChoisies.remove(cle);
        }
      });

  Future<void> _confirmer() async {
    setState(() => _submitting = true);
    try {
      final creances = _apercu!.lignes
          .where((l) => !l.estCredit && _creChoisie(l))
          .map((l) => {'document': l.document, 'documentId': l.documentId})
          .toList();
      await ref.read(tresorerieDatasourceProvider).arreter(
            perimetre: widget.perimetre,
            perimetreId: widget.perimetreId,
            periodeDebut: _debut,
            periodeFin: _fin,
            modePaiement: _mode,
            cotisationIds: _cotisationsChoisies.toList(),
            creances: creances,
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
    final rien = apercu == null || apercu.lignes.isEmpty;

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
            _MessageCard('Impossible de calculer le décompte : $_erreur',
                Colors.red.shade900, const Color(0xFFFDECEA))
          else if (rien)
            const _MessageCard('Aucune cotisation ni créance sur cette période.',
                AppColors.label, AppColors.headerButton)
          else ...[
            _SyntheseCard(
              fonds: _totalFonds,
              compense: _totalCompense,
              net: _totalNet,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(
                  child: Text('Lignes à restituer / compenser',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.label)),
                ),
                TextButton(
                    onPressed: _toutCocher,
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Tout', style: TextStyle(fontSize: 12.5))),
                TextButton(
                    onPressed: _toutDecocher,
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Rien', style: TextStyle(fontSize: 12.5))),
              ],
            ),
            const SizedBox(height: 4),
            for (final g in _groupes) _GroupeCard(groupe: g, etat: this),
            const SizedBox(height: 8),
            if (_totalNet > 0) ...[
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
                onPressed:
                    _submitting || _loading || !_peutValider ? null : _confirmer,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: Text(!_peutValider
                    ? 'Sélectionnez au moins une cotisation'
                    : _totalNet > 0
                        ? 'Restituer ${CurrencyFormatter.format(_totalNet)}'
                        : 'Compenser (aucun versement)'),
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ),
    );
  }
}

/// Un bénéficiaire chauffeur : ses cotisations (crédit) et créances (débit).
class _GroupeBeneficiaire {
  final int chauffeurId;
  final String nom;
  final List<LigneArrete> cotisations = [];
  final List<LigneArrete> creances = [];
  _GroupeBeneficiaire(this.chauffeurId, this.nom);
}

class _SyntheseCard extends StatelessWidget {
  final double fonds;
  final double compense;
  final double net;
  const _SyntheseCard(
      {required this.fonds, required this.compense, required this.net});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.8)),
      child: Column(
        children: [
          _ligne('Fonds sélectionné', fonds, AppColors.dark),
          const Divider(height: 18),
          _ligne('− Créances compensées', compense, Colors.orange.shade900),
          const Divider(height: 18),
          _ligne('= Net à restituer', net, Colors.green.shade800, gras: true),
        ],
      ),
    );
  }

  Widget _ligne(String label, double montant, Color couleur,
      {bool gras = false}) {
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

/// Carte d'un bénéficiaire : cases à cocher des cotisations puis des créances,
/// et le net résultant pour ce chauffeur.
class _GroupeCard extends StatelessWidget {
  final _GroupeBeneficiaire groupe;
  final _ArreteFormPageState etat;
  const _GroupeCard({required this.groupe, required this.etat});

  static const _libellesDoc = {
    'RECETTE': 'Recette',
    'PENALITE': 'Pénalité',
    'CONTRAVENTION': 'Contravention',
  };

  @override
  Widget build(BuildContext context) {
    final net = etat._netGroupe(groupe);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(groupe.nom,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark)),
                ),
                Text('Net ${CurrencyFormatter.format(net)}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: net > 0
                            ? Colors.green.shade800
                            : AppColors.hint)),
              ],
            ),
          ),
          if (groupe.cotisations.isNotEmpty)
            _sousTitre('Cotisations (fonds)'),
          for (final l in groupe.cotisations)
            _tuile(
              context,
              titre: 'Cotisation',
              sousTitre: '#${l.documentId}',
              montant: l.montant,
              couleurMontant: AppColors.dark,
              coche: etat._cotChoisie(l),
              onChanged: (v) => etat.basculeCotisation(l.documentId, v),
            ),
          if (groupe.creances.isNotEmpty) _sousTitre('Créances à compenser'),
          for (final l in groupe.creances)
            _tuile(
              context,
              titre: _libellesDoc[l.document] ?? l.document,
              sousTitre: '#${l.documentId}',
              montant: l.montant,
              couleurMontant: Colors.orange.shade900,
              coche: etat._creChoisie(l),
              onChanged: (v) => etat.basculeCreance(l, v),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _sousTitre(String texte) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        child: Text(texte,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.hint)),
      );

  Widget _tuile(
    BuildContext context, {
    required String titre,
    required String sousTitre,
    required double montant,
    required Color couleurMontant,
    required bool coche,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!coche),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: coche,
              onChanged: onChanged,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(
              child: Text('$titre  $sousTitre',
                  style: const TextStyle(fontSize: 13, color: AppColors.dark)),
            ),
            Text(CurrencyFormatter.format(montant),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: couleurMontant)),
            const SizedBox(width: 8),
          ],
        ),
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
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(message, style: TextStyle(fontSize: 13, color: fg)),
    );
  }
}
