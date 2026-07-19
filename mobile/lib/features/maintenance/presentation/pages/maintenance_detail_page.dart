import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/maintenance.dart';
import '../../../operation_financiere/domain/entities/element_maintenance.dart';
import '../providers/maintenance_provider.dart';
import '../../../operation_financiere/presentation/providers/operation_financiere_provider.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _TerminerMaintenanceDialog(
        controller: ctrl,
        typeLabel: _displayType(),
      ),
    );
    if (confirmed != true) return;

    final cout = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
    final error = await ref
        .read(maintenanceNotifierProvider.notifier)
        .completeMaintenance(_m.id!, cout);

    if (!mounted) return;
    if (error != null) {
      _showToast(error, error: true);
    } else {
      ref.read(operationFinanciereNotifierProvider.notifier).loadAll();
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
                              if (_m.type.isNotEmpty &&
                                  _m.categorieTypeLibelle != null &&
                                  _m.type != _m.categorieTypeLibelle) ...[
                                const SizedBox(height: 2),
                                Text(_m.type,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: _kLabel,
                                        letterSpacing: 0.2)),
                              ],
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

                  // ── Planification ─────────────────────────────────────
                  _sectionCard(
                    icon: Icons.event_note_outlined,
                    title: 'Planification',
                    rows: [
                      _infoRow(
                          Icons.calendar_today_outlined,
                          'Date prévue',
                          _fmtDate(_m.datePrevue)),
                      if (_m.dateEffectuee != null)
                        _infoRow(
                            Icons.check_circle_outline_rounded,
                            'Date effectuée',
                            _fmtDate(_m.dateEffectuee!),
                            valueColor: const Color(0xFF2E7D32)),
                      if (_m.dureeHeures != null)
                        _infoRow(Icons.timer_outlined, 'Durée',
                            '${_m.dureeHeures} heure(s)'),
                      if (_m.categorieTypeLibelle != null)
                        _infoRow(Icons.label_outline_rounded, 'Catégorie',
                            _m.categorieTypeLibelle!),
                    ],
                  ),

                  // ── Véhicule ──────────────────────────────────────────
                  if (_m.vehiculeNom != null || _m.vehiculeId != null)
                    _sectionCard(
                      icon: Icons.directions_car_outlined,
                      title: 'Véhicule',
                      rows: [
                        _infoRow(
                            Icons.directions_car_filled_rounded,
                            'Véhicule',
                            _m.vehiculeNom ??
                                'Véhicule #${_m.vehiculeId}'),
                      ],
                    ),

                  // ── Informations ──────────────────────────────────────
                  if (_m.prestataire != null ||
                      _m.kilometrageAuMoment != null ||
                      _m.kilometrageProchaine != null ||
                      _m.cout != null)
                    _sectionCard(
                      icon: Icons.info_outline_rounded,
                      title: 'Informations',
                      rows: [
                        if (_m.prestataire != null)
                          _infoRow(Icons.store_outlined, 'Prestataire',
                              _m.prestataire!),
                        if (_m.kilometrageAuMoment != null)
                          _infoRow(Icons.speed_outlined, 'Kilométrage',
                              '${_m.kilometrageAuMoment} km'),
                        if (_m.kilometrageProchaine != null)
                          _infoRow(Icons.arrow_forward_rounded,
                              'Prochain entretien',
                              '${_m.kilometrageProchaine} km'),
                        if (_m.cout != null)
                          _infoRow(Icons.payments_outlined, 'Coût',
                              _fmtMontant(_m.cout!),
                              valueColor: const Color(0xFFB71C1C)),
                      ],
                    ),

                  // ── Description ───────────────────────────────────────
                  if (_m.description != null && _m.description!.isNotEmpty)
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                              Icons.notes_outlined, 'Description'),
                          const SizedBox(height: 12),
                          Text(
                            _m.description!,
                            style: const TextStyle(
                                fontSize: 14,
                                color: _kDark,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),

                  // ── Éléments ──────────────────────────────────────────
                  if (_m.detailMaintenance != null &&
                      _m.detailMaintenance!.elements.isNotEmpty)
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                              Icons.checklist_rounded, 'Éléments'),
                          const SizedBox(height: 12),
                          ..._m.detailMaintenance!.elements
                              .map((e) => _elementRow(e)),
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
                                _fmtMontant(_m.detailMaintenance!.elements
                                    .fold(0.0, (s, e) => s + e.montant)),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _kAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // ── Actions ───────────────────────────────────────────
                  if (_m.isPending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _complete,
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Terminer la maintenance',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),

                  // L'annulation n'est proposée que si la maintenance ne l'est
                  // pas déjà (évite l'erreur « déjà annulée »).
                  if (_m.statut != 'ANNULEE')
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

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> rows,
  }) =>
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(icon, title),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
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
            child: Text(
              e.effectiveLibelle,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kDark),
            ),
          ),
          Text(
            _fmtMontant(e.montant),
            style: const TextStyle(
                fontSize: 12, color: _kAccent, fontWeight: FontWeight.w700),
          ),
        ]),
      );
}

// ── Popup « Terminer la maintenance » (premium, alignée charte) ────────────────

/// Dialogue de clôture d'une maintenance : en-tête à icône teintée, champ de
/// saisie du coût réel stylé (suffixe XOF) et actions Annuler / Confirmer.
/// Le bouton Confirmer reste inactif tant qu'aucun coût n'est saisi.
class _TerminerMaintenanceDialog extends StatefulWidget {
  final TextEditingController controller;
  final String typeLabel;

  const _TerminerMaintenanceDialog({
    required this.controller,
    required this.typeLabel,
  });

  @override
  State<_TerminerMaintenanceDialog> createState() =>
      _TerminerMaintenanceDialogState();
}

class _TerminerMaintenanceDialogState
    extends State<_TerminerMaintenanceDialog> {
  bool get _valide => widget.controller.text.trim().isNotEmpty;

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
                if (_valide) Navigator.pop(context, true);
              },
            ),
            const SizedBox(height: 22),
            // ── Actions ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
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
                      onPressed:
                          _valide ? () => Navigator.pop(context, true) : null,
                      icon: const Icon(Icons.check_rounded, size: 19),
                      label: const Text('Confirmer',
                          style: TextStyle(
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
