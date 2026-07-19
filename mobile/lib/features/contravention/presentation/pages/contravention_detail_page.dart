import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/contravention.dart';
import '../providers/contravention_provider.dart';
import 'contravention_form_page.dart';

/// Détail premium d'une contravention : synthèse en tête, puis toutes les
/// informations regroupées par section, et les actions (modifier, payer,
/// supprimer). Renvoie `true` au pop si une modification a eu lieu.
class ContraventionDetailPage extends ConsumerStatefulWidget {
  final Contravention contravention;
  const ContraventionDetailPage({super.key, required this.contravention});

  @override
  ConsumerState<ContraventionDetailPage> createState() =>
      _ContraventionDetailPageState();
}

class _ContraventionDetailPageState
    extends ConsumerState<ContraventionDetailPage> {
  final _money = NumberFormat('#,##0', 'fr_FR');

  Contravention get c => widget.contravention;

  static const _rouge = Color(0xFFB71C1C);
  static const _ambre = Color(0xFF854F0B);
  static const _vert = Color(0xFF2E7D32);

  // ── Dérivés ──────────────────────────────────────────────────────────────

  (String, Color) get _statut {
    if (c.isPaid) return ('Payé', _vert);
    if (c.isPartial) return ('Partiellement payé', _ambre);
    return ('En attente', AppColors.warning);
  }

  (String, Color, IconData)? get _rattachement {
    switch (c.statutRattachement) {
      case 'AUTO':
        return ('Rattaché automatiquement', _vert, Icons.person_search_outlined);
      case 'MANUEL':
        return ('Rattaché manuellement', _vert, Icons.person_outline);
      case 'A_RATTACHER':
        return ('À rattacher', _ambre, Icons.help_outline);
      default:
        return null;
    }
  }

  double get _reste =>
      (c.montant - (c.montantPaye ?? 0)).clamp(0, double.infinity);

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _edit() async {
    final res = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ContraventionFormPage(initial: c)));
    if (res == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _reverser() async {
    // Reversement à l'État : porte sur le montant total de la contravention et
    // peut se faire même si elle n'a pas été payée par le chauffeur. Le
    // remboursement chauffeur (PAYE) se fait, lui, côté finance via la
    // compensation lors de la restitution des cotisations (arrêté de compte).
    final montant = c.montant;
    if (montant <= 0) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icône dans une pastille teintée.
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_outlined,
                      size: 28, color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Reverser à l\'État',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                    letterSpacing: -0.4),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le montant total de la contravention sera reversé à l\'État. '
                'Une opération « Reversement contravention » sera enregistrée.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.5, height: 1.4, color: AppColors.label),
              ),
              const SizedBox(height: 18),
              // Montant à reverser — lecture seule (cadenas = non modifiable).
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline,
                          size: 18, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Montant à reverser',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark)),
                          const SizedBox(height: 2),
                          Text('${_money.format(montant)} XOF',
                              style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.label,
                          side: const BorderSide(color: AppColors.border),
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
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon:
                            const Icon(Icons.account_balance_outlined, size: 18),
                        label: const Text('Reverser',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final error = await ref
        .read(contraventionNotifierProvider.notifier)
        .reverserContravention(c.id!);
    if (!mounted) return;
    if (error != null) {
      _toast(error, err: true);
    } else {
      _toast('Contravention reversée');
      Navigator.pop(context, true);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la contravention'),
        content: const Text('Cette action est définitive. Confirmer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _rouge),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await ref
        .read(contraventionNotifierProvider.notifier)
        .deleteContravention(c.id!);
    if (!mounted) return;
    if (error != null) {
      _toast(error, err: true);
    } else {
      Navigator.pop(context, true);
    }
  }

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: err ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.scaffold,
        appBar: AppHeader(
          title: 'Contravention',
          action: AppHeaderAction(icon: Icons.edit_outlined, onTap: _edit),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _hero(),
            const SizedBox(height: 14),
            _section('Infraction', Icons.gavel_outlined, [
              _row('Numéro', c.numeroContravention),
              _row('Code', c.codeInfraction),
              _row("Type d'infraction", c.typeInfraction),
              _row('Date', _fmtDate(c.dateInfraction)),
              _row('Heure', _fmtHeure(c.heureInfraction)),
              _row('Vitesse relevée',
                  c.vitesseRelevee != null ? '${c.vitesseRelevee} km/h' : null),
              _row('Lieu', c.lieu),
              _row('Description', c.description),
            ]),
            _section('Véhicule et chauffeur', Icons.directions_car_outlined, [
              _row('Véhicule', c.vehiculeNom),
              _row('Chauffeur', c.chauffeurNom),
              _row('Rattachement', _rattachement?.$1),
            ]),
            _section('Montants', Icons.payments_outlined, [
              _row('Montant', '${_money.format(c.montant)} XOF', strong: true),
              _row('Cotisation',
                  c.cotisation != null ? '${_money.format(c.cotisation)} XOF' : null),
              _row('Déjà payé',
                  c.montantPaye != null ? '${_money.format(c.montantPaye)} XOF' : null),
              _row('Reste à payer',
                  c.isPaid ? '0 XOF' : '${_money.format(_reste)} XOF'),
              _row('Statut', _statut.$1),
              _row('Date de paiement',
                  c.datePaiement != null ? _fmtDate(c.datePaiement!) : null),
            ]),
            if (c.documentSourcePath != null)
              _section('Document source', Icons.description_outlined, [
                _row('Relevé PDF', 'Importé depuis un relevé'),
              ]),
            const SizedBox(height: 6),
            _actions(),
          ],
        ),
      );
  }

  Widget _hero() {
    final (statutLabel, statutColor) = _statut;
    final rattach = _rattachement;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_money.format(c.montant)} XOF',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                  letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(statutLabel, statutColor),
            if (rattach != null) _chip(rattach.$1, rattach.$2, icon: rattach.$3),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.directions_car_outlined,
                size: 16, color: AppColors.label),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                [
                  c.vehiculeNom ?? 'Véhicule non défini',
                  if (c.chauffeurNom != null) c.chauffeurNom!,
                ].join('  ·  '),
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _actions() {
    // Le paiement (PAYE) n'est plus déclenché ici : il se fait côté finance via
    // la compensation lors de la restitution des cotisations. Le module
    // contraventions ne propose que le reversement à l'État (REVERSE).
    final reversable = !c.isReverse && !c.isCancelled;
    return Row(children: [
      if (reversable)
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _reverser,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.account_balance_outlined, size: 18),
              label: const Text('Reverser',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      if (reversable) const SizedBox(width: 12),
      SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          onPressed: _delete,
          style: OutlinedButton.styleFrom(
            foregroundColor: _rouge,
            side: const BorderSide(color: Color(0xFFF0C6C6)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Supprimer',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  // ── Composants ──────────────────────────────────────────────────────────

  Widget _section(String title, IconData icon, List<Widget> rows) {
    final visibles = rows.whereType<Widget>().toList();
    if (visibles.every((w) => w is SizedBox)) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark)),
          ]),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String? value, {bool strong = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.label)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.dark)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String? _fmtHeure(String? h) {
    if (h == null || h.length < 5) return null;
    return h.substring(0, 5);
  }
}
