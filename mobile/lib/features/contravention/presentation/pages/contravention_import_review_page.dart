import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../chauffeur/domain/entities/chauffeur.dart';
import '../../../chauffeur/presentation/pages/chauffeur_selector_page.dart';
import '../../data/models/apercu_import_model.dart';
import '../../data/models/contravention_model.dart';
import '../providers/contravention_provider.dart';

/// Écran de revue des contraventions extraites d'un relevé PDF. L'exploitant
/// vérifie le relevé, ajuste au besoin le chauffeur proposé, puis confirme
/// l'import de l'ensemble des contraventions détectées.
class ContraventionImportReviewPage extends ConsumerStatefulWidget {
  final ApercuImportModel apercu;
  const ContraventionImportReviewPage({super.key, required this.apercu});

  @override
  ConsumerState<ContraventionImportReviewPage> createState() =>
      _ContraventionImportReviewPageState();
}

class _ContraventionImportReviewPageState
    extends ConsumerState<ContraventionImportReviewPage> {
  static final _money = NumberFormat('#,##0', 'fr_FR');

  // Accents alignés sur la carte contravention.
  static const _rouge = Color(0xFFB71C1C);
  static const _rougeBg = Color(0xFFFCEBEB);
  static const _ambre = Color(0xFF854F0B);
  static const _ambreBg = Color(0xFFFAEEDA);
  static const _vert = Color(0xFF2E7D32);
  static const _vertBg = Color(0xFFEAF3DE);

  late final List<ContraventionModel> _items;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _items = List<ContraventionModel>.from(widget.apercu.candidats);
  }

  double get _total => _items.fold<double>(0, (s, c) => s + c.montant);

  Future<void> _changerChauffeur(int index) async {
    final chauffeur = await Navigator.push<Chauffeur>(
      context,
      MaterialPageRoute(builder: (_) => const ChauffeurSelectorPage()),
    );
    if (chauffeur == null || chauffeur.id == null) return;
    setState(() {
      _items[index] = ContraventionModel.fromEntity(_items[index].copyWith(
        chauffeurId: chauffeur.id,
        chauffeurNom: '${chauffeur.prenom} ${chauffeur.nom}'.trim(),
        statutRattachement: 'MANUEL',
      ));
    });
  }

  Future<void> _confirmer() async {
    if (_items.isEmpty) return;

    setState(() => _loading = true);
    try {
      final res =
          await ref.read(contraventionImportProvider).confirmer(_items);
      if (!mounted) return;
      final creees = res['contraventionsCreees'] ?? _items.length;
      final rattachees = res['contraventionsRattachees'] ?? 0;
      _toast('$creees contravention(s) importée(s), '
          '$rattachees rattachée(s) à un chauffeur.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(_messageErreur(e), erreur: true);
    }
  }

  void _toast(String message, {bool erreur = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: erreur ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
  }

  String _messageErreur(Object e) {
    try {
      final m = (e as dynamic).message;
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return "Échec de la confirmation de l'import.";
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.apercu;
    final bloque = a.vehiculeInconnu || a.vehiculeId == null;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: "Revue de l'import"),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? _EmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _resume(a, bloque),
                      if (!bloque) ...[
                        const SizedBox(height: 16),
                        const Text('Contraventions détectées',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dark)),
                        const SizedBox(height: 10),
                        for (var i = 0; i < _items.length; i++)
                          _carte(_items[i], i),
                      ],
                    ],
                  ),
          ),
          // Barre de confirmation intégrée au flux (et non en bottomNavigationBar) :
          // cette page est un Scaffold imbriqué dans le hub ; un bottomNavigationBar
          // y écrase le corps jusqu'à le faire disparaître. Placée sous l'Expanded,
          // la barre reste toujours sous la liste.
          if (!(_items.isEmpty || bloque)) _barreConfirmer(),
        ],
      ),
    );
  }

  // ── Résumé du relevé ──────────────────────────────────────────────────────

  Widget _resume(ApercuImportModel a, bool bloque) {
    final immat = a.vehiculeImmatriculation ?? a.plaque ?? 'Véhicule inconnu';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bloque ? _rougeBg : AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_car_outlined,
                    size: 22,
                    color: bloque ? _rouge : AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(immat,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 2),
                    Text('${_items.length} contravention(s) détectée(s)',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.label)),
                  ],
                ),
              ),
            ],
          ),
          if (!bloque) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Montant total à importer',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.primaryDark)),
                  const SizedBox(height: 2),
                  Text('${_money.format(_total)} XOF',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                          letterSpacing: -0.5)),
                ],
              ),
            ),
          ],
          if (bloque)
            _banniere(
              icon: Icons.error_outline_rounded,
              color: _rouge,
              bg: _rougeBg,
              texte: 'Plaque « ${a.plaque ?? '?'} » non reconnue : aucun '
                  'véhicule correspondant. Import impossible.',
            ),
          if (a.doublonsIgnores.isNotEmpty)
            _banniere(
              icon: Icons.info_outline_rounded,
              color: _ambre,
              bg: _ambreBg,
              texte: '${a.doublonsIgnores.length} contravention(s) déjà '
                  'enregistrée(s), ignorée(s).',
            ),
        ],
      ),
    );
  }

  Widget _banniere({
    required IconData icon,
    required Color color,
    required Color bg,
    required String texte,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
        ],
      ),
    );
  }

  // ── Carte contravention candidate ─────────────────────────────────────────

  Widget _carte(ContraventionModel c, int index) {
    final aRattacher = c.chauffeurId == null;
    final d = c.dateInfraction;
    final dateStr = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    final heure = (c.heureInfraction != null && c.heureInfraction!.length >= 5)
        ? c.heureInfraction!.substring(0, 5)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  c.typeInfraction ?? c.description ?? 'Infraction',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark),
                ),
              ),
              const SizedBox(width: 8),
              Text('${_money.format(c.montant)} XOF',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark)),
            ],
          ),
          const SizedBox(height: 9),
          Row(children: [
            _metaItem(Icons.calendar_today_outlined,
                heure != null ? '$dateStr · $heure' : dateStr),
            if (c.vitesseRelevee != null) ...[
              const SizedBox(width: 13),
              _metaItem(Icons.speed_outlined, '${c.vitesseRelevee} km/h'),
            ],
          ]),
          const SizedBox(height: 10),
          _rattachementRow(c, index, aRattacher),
        ],
      ),
    );
  }

  Widget _rattachementRow(ContraventionModel c, int index, bool aRattacher) {
    final color = aRattacher ? _ambre : _vert;
    final bg = aRattacher ? _ambreBg : _vertBg;
    return GestureDetector(
      onTap: () => _changerChauffeur(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(aRattacher ? Icons.person_off_outlined : Icons.person,
                size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                aRattacher
                    ? 'À rattacher — choisir un chauffeur'
                    : c.chauffeurNom ?? 'Chauffeur',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.edit_outlined, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.label),
      const SizedBox(width: 5),
      Text(text,
          style: const TextStyle(fontSize: 11.5, color: AppColors.label)),
    ]);
  }

  // ── Barre de confirmation ─────────────────────────────────────────────────

  Widget _barreConfirmer() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _confirmer,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.border,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(
                _loading
                    ? 'Import en cours…'
                    : 'Importer ${_items.length} contravention(s)',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

/// État vide : aucune nouvelle contravention à importer.
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: AppColors.hint),
            SizedBox(height: 16),
            Text(
              'Aucune nouvelle contravention à importer',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark),
            ),
            SizedBox(height: 6),
            Text(
              'Toutes les contraventions du relevé sont déjà enregistrées.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.label),
            ),
          ],
        ),
      ),
    );
  }
}
