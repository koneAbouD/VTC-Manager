import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../domain/entities/maintenance.dart';
import '../../../operation_financiere/domain/entities/element_maintenance.dart';
import '../providers/maintenance_provider.dart';
import '../../../operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../../../partenaire/presentation/providers/partenaire_providers.dart';
import '../../../../screens/finance/finance_refresh.dart';
import 'maintenance_form_page.dart';
import '../../../../core/theme/app_colors.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kPrimary = AppColors.primary;
const _kAccent  = Color(0xFFE65100);
const _kDark    = Color(0xFF1A1A2E);
const _kBorder  = Color(0xFFE3E6EE);
const _kLabel   = Color(0xFF6B7280);
const _kBg      = Color(0xFFF8F9FB);

// ── Page ──────────────────────────────────────────────────────────────────────

class MaintenanceDetailPage extends ConsumerStatefulWidget {
  final Maintenance maintenance;
  const MaintenanceDetailPage({super.key, required this.maintenance});

  @override
  ConsumerState<MaintenanceDetailPage> createState() =>
      _MaintenanceDetailPageState();
}

class _MaintenanceDetailPageState
    extends ConsumerState<MaintenanceDetailPage> {
  late Maintenance _m;

  @override
  void initState() {
    super.initState();
    _m = widget.maintenance;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      DateFormat('dd MMM yyyy', 'fr_FR').format(d);

  String _fmtMontant(double v) {
    final f = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    return f.format(v);
  }

  Color _couleurStatut(String? s) => switch (s) {
        'TERMINEE'  => const Color(0xFF2E7D32),
        'EN_COURS'  => const Color(0xFF1565C0),
        'ANNULEE'   => const Color(0xFF616161),
        _           => const Color(0xFFE65100),
      };

  String _labelStatut(String? s) => switch (s) {
        'TERMINEE'  => 'Terminée',
        'EN_COURS'  => 'En cours',
        'ANNULEE'   => 'Annulée',
        _           => 'Planifiée',
      };

  /// Icône dérivée du libellé de catégorie retourné par le backend.
  IconData _iconeType(String t) {
    final u = t.toUpperCase();
    if (u.contains('VIDANGE'))     return Icons.oil_barrel_outlined;
    if (u.contains('REVISION'))    return Icons.settings_outlined;
    if (u.contains('REPARATION'))  return Icons.build_outlined;
    if (u.contains('CONTROLE'))    return Icons.fact_check_outlined;
    if (u.contains('PNEUMATIQUE')) return Icons.tire_repair_outlined;
    if (u.contains('FREINAGE'))    return Icons.emergency_outlined;
    if (u.contains('PARALISE') || u.contains('PARALYSIE')) {
      return Icons.car_crash_outlined;
    }
    if (u.contains('TOLERIE') || u.contains('TÔLERIE')) {
      return Icons.car_repair_outlined;
    }
    if (u.contains('PEINTURE'))    return Icons.brush_outlined;
    return Icons.construction_outlined;
  }

  String _displayType() =>
      (_m.categorieTypeLibelle?.isNotEmpty == true)
          ? _m.categorieTypeLibelle!
          : _m.type;

  // ── Actions ───────────────────────────────────────────────────────────────

  void _showToast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
          ),
        ]),
        backgroundColor:
            error ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: error ? const Duration(seconds: 4) : const Duration(seconds: 2),
      ));
  }

  Future<void> _edit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => MaintenanceFormPage(initial: _m)),
    );
    if (mounted && result == true) Navigator.pop(context, true);
  }

  Future<void> _complete() async {
    final ctrl = TextEditingController();
    final choix = await showDialog<_ChoixCloture>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _TerminerMaintenanceDialog(
        controller: ctrl,
        typeLabel: _displayType(),
        maintenance: _m,
      ),
    );
    if (choix == null) return;

    final cout = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
    final error = await ref
        .read(maintenanceNotifierProvider.notifier)
        .completeMaintenance(_m.id!, cout,
            aCredit: choix.aCredit, dateEcheance: choix.echeance);

    if (!mounted) return;
    if (error != null) {
      _showToast(error, error: true);
    } else {
      ref.read(operationFinanciereNotifierProvider.notifier).loadAll();
      // Une clôture à crédit vient de créer des dettes : l'échéancier et le
      // passif doivent les refléter sans attendre.
      refreshFinances(ref);
      Navigator.pop(context, true);
    }
  }

  Future<void> _annuler() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler la maintenance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
            'La maintenance sera marquée comme annulée. Confirmer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await ref
        .read(maintenanceNotifierProvider.notifier)
        .annulerMaintenance(_m.id!);

    if (!mounted) return;
    if (error != null) {
      _showToast(error, error: true);
    } else {
      Navigator.pop(context, true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final statColor = _couleurStatut(_m.statut);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppHeader(
        title: 'Détail maintenance',
        action: AppHeaderAction(onTap: _edit, icon: Icons.edit_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [

                  // ── Hero ─────────────────────────────────────────────
                  _card(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: statColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_iconeType(_m.type),
                              color: statColor, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayType(),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _kDark,
                                    letterSpacing: -0.3),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _labelStatut(_m.statut),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: statColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Rubriques de l'intervention ───────────────────────
                  // Une seule carte : les rubriques se suivent, séparées par un
                  // filet, au lieu de flotter chacune sur la sienne.
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _rubriques(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Actions ───────────────────────────────────────────
                  // Maintenance planifiée : « Annuler » et « Terminer » sur une
                  // même ligne. Sinon (déjà terminée, etc.) : « Annuler » seul,
                  // proposé tant qu'elle n'est pas déjà annulée.
                  if (_m.isPending)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _annuler,
                              icon: const Icon(Icons.cancel_outlined,
                                  color: Colors.red),
                              label: const Text('Annuler',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Colors.red, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _complete,
                              icon: const Icon(
                                  Icons.check_circle_outline_rounded),
                              label: const Text('Terminer',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (_m.statut != 'ANNULEE')
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _annuler,
                        icon: const Icon(Icons.cancel_outlined,
                            color: Colors.red),
                        label: const Text('Annuler',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  // ── Builders ──────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: child,
      );

  /// Les rubriques de la carte unique, dans l'ordre, chacune précédée d'un
  /// filet. Seule la planification est toujours là : elle ouvre la carte, ce
  /// qui dispense les suivantes de savoir si quelque chose les précède.
  List<Widget> _rubriques() {
    final rubriques = <Widget>[
      _section(
        icon: Icons.event_note_outlined,
        title: 'Planification',
        rows: [
          _infoRow(Icons.calendar_today_outlined, 'Date prévue',
              _fmtDate(_m.datePrevue)),
          if (_m.dateEffectuee != null)
            _infoRow(Icons.check_circle_outline_rounded, 'Date effectuée',
                _fmtDate(_m.dateEffectuee!),
                valueColor: const Color(0xFF2E7D32)),
          if (_m.dureeHeures != null)
            _infoRow(
                Icons.timer_outlined, 'Durée', '${_m.dureeHeures} heure(s)'),
          if (_m.categorieTypeLibelle != null)
            _infoRow(Icons.label_outline_rounded, 'Catégorie',
                _m.categorieTypeLibelle!),
        ],
      ),
    ];

    if (_m.vehiculeImmatriculation != null || _m.vehiculeId != null) {
      rubriques
        ..add(const _FiletRubrique())
        ..add(_section(
          icon: Icons.directions_car_outlined,
          title: 'Véhicule',
          rows: [
            // L'immatriculation suffit à désigner le véhicule ; repli sur
            // l'identifiant tant qu'elle n'est pas renseignée.
            _infoRow(
                Icons.directions_car_filled_rounded,
                'Véhicule',
                _m.vehiculeImmatriculation?.isNotEmpty == true
                    ? _m.vehiculeImmatriculation!
                    : 'Véhicule #${_m.vehiculeId}'),
          ],
        ));
    }

    // Le reste à payer dépend d'une requête : il porte son propre filet, faute
    // de savoir d'ici s'il aura quelque chose à afficher.
    if (_m.id != null) rubriques.add(_blocDettes());

    if (_m.partenaireNom != null ||
        _m.kilometrageAuMoment != null ||
        _m.kilometrageProchaine != null ||
        _m.cout != null) {
      rubriques
        ..add(const _FiletRubrique())
        ..add(_section(
          icon: Icons.info_outline_rounded,
          title: 'Informations',
          rows: [
            if (_m.partenaireNom != null)
              _infoRow(Icons.store_outlined, 'Partenaire', _m.partenaireNom!),
            if (_m.kilometrageAuMoment != null)
              _infoRow(Icons.speed_outlined, 'Kilométrage',
                  '${_m.kilometrageAuMoment} km'),
            if (_m.kilometrageProchaine != null)
              _infoRow(Icons.arrow_forward_rounded, 'Prochain entretien',
                  '${_m.kilometrageProchaine} km'),
            if (_m.cout != null)
              _infoRow(Icons.payments_outlined, 'Coût', _fmtMontant(_m.cout!),
                  valueColor: const Color(0xFFB71C1C)),
          ],
        ));
    }

    if (_m.description != null && _m.description!.isNotEmpty) {
      rubriques
        ..add(const _FiletRubrique())
        ..add(_rubrique(
          children: [
            _sectionHeader(Icons.notes_outlined, 'Description'),
            const SizedBox(height: 12),
            Text(
              _m.description!,
              style: const TextStyle(fontSize: 14, color: _kDark, height: 1.5),
            ),
          ],
        ));
    }

    final elements = _m.detailMaintenance?.elements ?? const [];
    if (elements.isNotEmpty) {
      rubriques
        ..add(const _FiletRubrique())
        ..add(_rubrique(
          children: [
            _sectionHeader(Icons.checklist_rounded, 'Éléments'),
            const SizedBox(height: 12),
            ...elements.map((e) => _elementRow(e)),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kDark)),
                Text(
                  _fmtMontant(elements.fold(0.0, (s, e) => s + e.montant)),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kAccent),
                ),
              ],
            ),
          ],
        ));
    }

    return rubriques;
  }

  /// Ce que l'intervention a laissé à payer. Silencieux quand elle a été
  /// réglée sur place — la majorité des cas.
  Widget _blocDettes() {
    final dettes = ref.watch(facturesDeMaintenanceProvider(_m.id!));
    return dettes.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (liste) {
        final ouvertes = liste.where((f) => f.restantDu > 0).toList();
        if (ouvertes.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _FiletRubrique(),
            _section(
              icon: Icons.schedule_outlined,
              title: ouvertes.length == 1 ? 'Reste à payer' : 'Restes à payer',
              rows: [
                for (final f in ouvertes)
                  _infoRow(Icons.store_outlined,
                      f.partenaireNom ?? 'Partenaire', _fmtMontant(f.restantDu),
                      valueColor: _kAccent),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Une rubrique de la carte : le fond, la bordure et les angles appartiennent
  /// à la carte, la rubrique n'apporte que son contenu et sa marge intérieure.
  Widget _rubrique({required List<Widget> children}) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> rows,
  }) =>
      _rubrique(
        children: [
          _sectionHeader(icon, title),
          const SizedBox(height: 12),
          ...rows,
        ],
      );

  Widget _sectionHeader(IconData icon, String title) => Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: _kPrimary),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kDark,
                letterSpacing: -0.2)),
      ]);

  Widget _infoRow(IconData icon, String label, String value,
          {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: _kLabel),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: _kLabel)),
            ),
            Expanded(
              flex: 3,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? _kDark),
              ),
            ),
          ],
        ),
      );

  Widget _elementRow(ElementMaintenance e) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3EB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kAccent.withValues(alpha: 0.20)),
        ),
        child: Row(children: [
          const Icon(Icons.build_circle_outlined, size: 14, color: _kAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.libelleAvecQuantite,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kDark),
                ),
                // Qui a fourni la ligne : le sien, ou celui de l'intervention.
                // La nuance se lit à la graisse, sans deuxième colonne.
                if (_nomPrestataire(e) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_outlined,
                            size: 11, color: _kLabel),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _nomPrestataire(e)!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: _kLabel,
                                fontWeight: e.partenaireNom != null
                                    ? FontWeight.w600
                                    : FontWeight.w400),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtMontant(e.montant),
            style: const TextStyle(
                fontSize: 12, color: _kAccent, fontWeight: FontWeight.w700),
          ),
        ]),
      );

  /// Prestataire affiché pour une ligne : le sien s'il en a un, sinon celui de
  /// l'intervention. Null quand aucun des deux n'est renseigné.
  String? _nomPrestataire(ElementMaintenance e) =>
      e.partenaireNom ?? _m.partenaireNom;
}

/// Filet séparant deux rubriques. Pleine largeur : elles se lisent comme les
/// rangées d'une même carte, non comme des blocs rapportés.
class _FiletRubrique extends StatelessWidget {
  const _FiletRubrique();

  @override
  Widget build(BuildContext context) => Container(height: 1, color: _kBorder);
}

// ── Popup « Terminer la maintenance » (premium, alignée charte) ────────────────

/// Ce que l'utilisateur a décidé en clôturant : payé sur place, ou laissé à
/// payer avec une échéance.
class _ChoixCloture {
  final bool aCredit;
  final DateTime? echeance;
  const _ChoixCloture({required this.aCredit, this.echeance});
}

/// Dialogue de clôture d'une maintenance : coût réel, puis la seule question
/// qui change la suite — réglé maintenant, ou à payer ? À crédit, l'écran
/// annonce les dettes qui vont naître, avant de valider.
class _TerminerMaintenanceDialog extends StatefulWidget {
  final TextEditingController controller;
  final String typeLabel;
  final Maintenance maintenance;

  const _TerminerMaintenanceDialog({
    required this.controller,
    required this.typeLabel,
    required this.maintenance,
  });

  @override
  State<_TerminerMaintenanceDialog> createState() =>
      _TerminerMaintenanceDialogState();
}

class _TerminerMaintenanceDialogState
    extends State<_TerminerMaintenanceDialog> {
  bool _aCredit = false;
  DateTime _echeance = DateTime.now();

  bool get _valide => widget.controller.text.trim().isNotEmpty;

  double get _cout =>
      double.tryParse(widget.controller.text.replaceAll(',', '.')) ?? 0;

  /// Aperçu de la répartition, calqué sur la règle du serveur : les lignes vont
  /// à leur prestataire, celles qui n'en ont pas au partenaire de
  /// l'intervention, et tout écart avec le coût validé revient à ce dernier.
  List<MapEntry<String, double>> get _dettesPrevues {
    final principal = widget.maintenance.partenaireNom ?? 'Partenaire à définir';
    final elements = widget.maintenance.detailMaintenance?.elements
            .cast<ElementMaintenance>() ??
        const <ElementMaintenance>[];

    final parNom = <String, double>{};
    var totalLignes = 0.0;
    for (final el in elements) {
      final nom = el.partenaireNom ?? principal;
      parNom[nom] = (parNom[nom] ?? 0) + el.montant;
      totalLignes += el.montant;
    }
    final ecart = _cout - totalLignes;
    if (ecart.abs() > 0.5 || parNom.isEmpty) {
      parNom[principal] = (parNom[principal] ?? 0) + ecart;
    }
    return parNom.entries.where((e) => e.value > 0).toList();
  }

  void _confirmer() {
    Navigator.pop(
      context,
      _ChoixCloture(aCredit: _aCredit, echeance: _aCredit ? _echeance : null),
    );
  }

  Future<void> _choisirEcheance() async {
    // Le champ « Coût réel » a le focus dès l'ouverture : sans cela, le clavier
    // recouvrirait la molette, qui s'ouvre elle aussi par le bas.
    FocusScope.of(context).unfocus();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: _echeance,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      ),
    );
    if (picked != null) setState(() => _echeance = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.primaryDark, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Terminer la maintenance',
                          style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: _kDark,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Text(widget.typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: _kLabel)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Renseignez le coût réel des travaux pour clôturer cette maintenance.',
              style: TextStyle(fontSize: 13, height: 1.4, color: _kLabel),
            ),
            const SizedBox(height: 16),
            // ── Champ coût réel ────────────────────────────────────────
            TextField(
              controller: widget.controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _kDark),
              decoration: InputDecoration(
                labelText: 'Coût réel',
                labelStyle: const TextStyle(color: _kLabel),
                floatingLabelStyle:
                    const TextStyle(color: AppColors.primaryDark),
                prefixIcon: const Icon(Icons.payments_outlined,
                    color: _kPrimary, size: 20),
                suffixText: 'XOF',
                suffixStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _kLabel),
                filled: true,
                fillColor: const Color(0xFFF3F6F4),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kPrimary, width: 1.6),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onSubmitted: (_) {
                if (_valide) _confirmer();
              },
            ),
            const SizedBox(height: 16),

            // ── Réglé maintenant / à payer ─────────────────────────────
            // La question est posée ici parce que c'est le seul moment où la
            // réponse est connue — et elle décide de tout ce qui suit.
            _SegmentReglement(
              aCredit: _aCredit,
              onChanged: (v) => setState(() => _aCredit = v),
            ),

            if (_aCredit) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: _choisirEcheance,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6F4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined,
                          size: 18, color: _kPrimary),
                      const SizedBox(width: 10),
                      const Text('Échéance',
                          style: TextStyle(fontSize: 13.5, color: _kLabel)),
                      const Spacer(),
                      Text(
                        DateFormat('dd MMM yyyy', 'fr_FR').format(_echeance),
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _kDark),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: _kLabel),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ApercuDettes(dettes: _dettesPrevues),
            ],

            const SizedBox(height: 22),
            // ── Actions ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kLabel,
                        side: const BorderSide(color: _kBorder),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Annuler',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _valide ? _confirmer : null,
                      icon: Icon(
                          _aCredit
                              ? Icons.receipt_long_rounded
                              : Icons.check_rounded,
                          size: 19),
                      label: Text(_aCredit ? 'Créer la dette' : 'Confirmer',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        disabledBackgroundColor: _kBorder,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sélecteur « réglé / à payer » ────────────────────────────────────────────
// Deux pavés côte à côte plutôt qu'un interrupteur : chaque issue est nommée,
// et l'on voit ce qu'on choisit sans avoir à deviner ce que « oui » signifie.
class _SegmentReglement extends StatelessWidget {
  final bool aCredit;
  final ValueChanged<bool> onChanged;

  const _SegmentReglement({required this.aCredit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OptionReglement(
            icone: Icons.payments_outlined,
            titre: 'Payer',
            sousTitre: 'Sort de la caisse',
            actif: !aCredit,
            couleur: _kPrimary,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OptionReglement(
            icone: Icons.schedule_outlined,
            titre: 'À payer',
            sousTitre: 'Crée une dette',
            actif: aCredit,
            couleur: _kAccent,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _OptionReglement extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String sousTitre;
  final bool actif;
  final Color couleur;
  final VoidCallback onTap;

  const _OptionReglement({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.actif,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: actif ? couleur.withValues(alpha: 0.10) : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: actif ? couleur : _kBorder,
            width: actif ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 19, color: actif ? couleur : _kLabel),
            const SizedBox(height: 6),
            Text(titre,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: actif ? couleur : _kDark)),
            const SizedBox(height: 1),
            Text(sousTitre,
                style: const TextStyle(fontSize: 11.5, color: _kLabel)),
          ],
        ),
      ),
    );
  }
}

// ── Aperçu des dettes à créer ────────────────────────────────────────────────
// Le récapitulatif est la contrepartie du choix « à payer » : on ne valide pas
// une dette sans savoir envers qui, ni de combien.
class _ApercuDettes extends StatelessWidget {
  final List<MapEntry<String, double>> dettes;

  const _ApercuDettes({required this.dettes});

  @override
  Widget build(BuildContext context) {
    if (dettes.isEmpty) return const SizedBox.shrink();
    final fmt = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dettes.length == 1
                ? 'Une dette sera créée :'
                : '${dettes.length} dettes seront créées :',
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: _kAccent),
          ),
          const SizedBox(height: 8),
          for (final d in dettes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(d.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: _kDark)),
                  ),
                  Text(fmt.format(d.value),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kDark)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
