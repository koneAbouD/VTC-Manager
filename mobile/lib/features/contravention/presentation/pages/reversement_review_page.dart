import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../data/models/apercu_reversement_model.dart';
import '../providers/contravention_provider.dart';

/// Revue d'une quittance importée avant reversement : en-tête du document,
/// lignes rapprochées (badges de statut), sélection des lignes reversables et
/// confirmation du reversement en lot (REVERSE + dépense en background).
class ReversementReviewPage extends ConsumerStatefulWidget {
  final ApercuReversementModel apercu;
  const ReversementReviewPage({super.key, required this.apercu});

  @override
  ConsumerState<ReversementReviewPage> createState() =>
      _ReversementReviewPageState();
}

class _ReversementReviewPageState extends ConsumerState<ReversementReviewPage> {
  static final _money = NumberFormat('#,##0', 'fr_FR');
  static final _date = DateFormat('dd/MM/yyyy');

  late final Set<int> _selectedIds = {
    for (final l in widget.apercu.lignes)
      if (l.reversable) l.contraventionId!,
  };
  bool _loading = false;

  List<LigneReversementModel> get _lignes => widget.apercu.lignes;

  double get _totalSelection => _lignes
      .where((l) => l.contraventionId != null &&
          _selectedIds.contains(l.contraventionId))
      .fold(0, (s, l) => s + (l.montantSysteme ?? 0));

  void _toggle(int id, bool value) => setState(() {
        if (value) {
          _selectedIds.add(id);
        } else {
          _selectedIds.remove(id);
        }
      });

  Future<void> _confirmer() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _loading = true);
    try {
      final bilan = await ref.read(reversementImportProvider).confirmer(
            _selectedIds.toList(),
            widget.apercu.referenceAudit,
          );
      if (!mounted) return;
      final reversees = (bilan['reversees'] as num?)?.toInt() ?? 0;
      _toast('$reversees contravention(s) reversée(s) à l\'État.');
      Navigator.pop(context, true);
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
        content: Text(message),
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
    return 'Échec du reversement.';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.apercu;
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Reverser une quittance'),
      body: Column(
        children: [
          _entete(a),
          Expanded(
            child: _lignes.isEmpty
                ? const _VideEtat()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _lignes.length,
                    itemBuilder: (_, i) => _ligneTile(_lignes[i]),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _barreConfirmation(),
    );
  }

  // ── En-tête quittance ──────────────────────────────────────────────────────
  Widget _entete(ApercuReversementModel a) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                    color: AppColors.primaryTint, shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_outlined,
                    size: 18, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.numeroLiquidation ?? a.numeroDemande ?? 'Quittance',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark)),
                    if (a.demandeur != null)
                      Text(a.demandeur!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.label)),
                  ],
                ),
              ),
              if (a.dateQuittance != null)
                Text(_date.format(a.dateQuittance!),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.hint)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total à reverser',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark)),
                      const SizedBox(height: 2),
                      Text('${_money.format(a.totalAReverser)} XOF',
                          style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                              letterSpacing: -0.4)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${a.nombreAReverser} à reverser',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Ligne ──────────────────────────────────────────────────────────────────
  Widget _ligneTile(LigneReversementModel l) {
    final (badgeLabel, badgeColor, badgeBg) = _badge(l.statut);
    final selected = l.contraventionId != null &&
        _selectedIds.contains(l.contraventionId);

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1),
      ),
      child: Row(
        children: [
          if (l.reversable)
            Checkbox(
              value: selected,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              onChanged: (v) => _toggle(l.contraventionId!, v ?? false),
            )
          else
            const SizedBox(width: 44),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.numeroContravention,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark)),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _pill(badgeLabel, badgeColor, badgeBg),
                    if (l.plaque != null)
                      Text(l.plaque!,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.label)),
                    if (l.codeInfraction != null)
                      Text('· ${l.codeInfraction}',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.hint)),
                    if (l.montantDivergent)
                      _pill('Montant ≠', AppColors.warning,
                          const Color(0xFFFAEEDA)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_money.format(l.montantSysteme ?? l.montantQuittance ?? 0)} XOF',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.dark),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
      );

  (String, Color, Color) _badge(StatutLigneReversement s) {
    switch (s) {
      case StatutLigneReversement.aReverser:
        return ('À reverser', AppColors.primaryDark, AppColors.primaryTint);
      case StatutLigneReversement.dejaReversee:
        return ('Déjà reversée', AppColors.label, const Color(0xFFEDF1F5));
      case StatutLigneReversement.introuvable:
        return ('Introuvable', AppColors.warning, const Color(0xFFFAEEDA));
      case StatutLigneReversement.inconnu:
        return ('—', AppColors.hint, const Color(0xFFEDF1F5));
    }
  }

  // ── Barre de confirmation ────────────────────────────────────────────────
  Widget _barreConfirmation() {
    final count = _selectedIds.length;
    final actif = count > 0 && !_loading;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sélection à reverser',
                      style:
                          TextStyle(fontSize: 11.5, color: AppColors.label)),
                  const SizedBox(height: 2),
                  Text('${_money.format(_totalSelection)} XOF',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: actif ? _confirmer : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.border,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.account_balance_outlined, size: 18),
              label: Text('Reverser${count > 0 ? ' ($count)' : ''}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideEtat extends StatelessWidget {
  const _VideEtat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: AppColors.hint),
            SizedBox(height: 12),
            Text('Aucune contravention trouvée sur cette quittance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.label)),
          ],
        ),
      ),
    );
  }
}
