import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../compte/presentation/providers/compte_providers.dart';
import '../../../cotisation/presentation/providers/cotisation_providers.dart';
import '../../../operation/presentation/providers/operation_providers.dart';
import '../../../recette/presentation/providers/recette_providers.dart';
import '../../domain/entities/canal_paiement.dart';
import '../../domain/entities/paiement.dart';
import '../providers/paiement_providers.dart';

/// Ouvre le paiement Mobile Money sous forme de popup (bottom sheet),
/// à l'image de « Encaisser » de l'app gestionnaire.
Future<bool?> showPaiementSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.scaffold,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _PaiementSheet(),
  );
}

class _Payable {
  final String typeCible; // RECETTE | COTISATION
  final int id;
  final String label;
  final double montant;
  const _Payable(this.typeCible, this.id, this.label, this.montant);

  String get cle => '$typeCible-$id';
}

class _PaiementSheet extends ConsumerStatefulWidget {
  const _PaiementSheet();

  @override
  ConsumerState<_PaiementSheet> createState() => _PaiementSheetState();
}

class _PaiementSheetState extends ConsumerState<_PaiementSheet> {
  String? _cibleCle;
  CanalPaiement _canal = CanalPaiement.wave;
  final _telephone = TextEditingController();
  bool _telInit = false;

  bool _enCours = false;
  Paiement? _paiement;
  Timer? _poll;

  @override
  void dispose() {
    _telephone.dispose();
    _poll?.cancel();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  List<_Payable> _payables() {
    final recettes = ref.watch(recettesProvider).valueOrNull ?? [];
    final cotisations = ref.watch(cotisationsProvider).valueOrNull ?? [];
    final items = <_Payable>[];
    for (final r in recettes) {
      if (r.resteAPayer) {
        items.add(_Payable(
            'RECETTE', r.id, 'Recette du ${Fmt.date(r.date)}', r.montantRestant!));
      }
    }
    for (final c in cotisations) {
      if (c.resteAPayer) {
        items.add(_Payable('COTISATION', c.id,
            c.nom ?? 'Cotisation du ${Fmt.date(c.date)}', c.montantRestant!));
      }
    }
    return items;
  }

  Future<void> _payer(_Payable cible) async {
    final tel = _telephone.text.trim();
    if (tel.length < 8) {
      _snack('Entrez un numéro Mobile Money valide.');
      return;
    }
    setState(() => _enCours = true);
    final result = await ref.read(initierPaiementUseCaseProvider).call(
          typeCible: cible.typeCible,
          cibleId: cible.id,
          canal: _canal,
          telephone: tel,
        );
    result.fold(
      (f) {
        setState(() => _enCours = false);
        _snack(f.message);
      },
      (p) {
        setState(() => _paiement = p);
        _demarrerSuivi(p.reference);
      },
    );
  }

  void _demarrerSuivi(String reference) {
    _poll?.cancel();
    int tentatives = 0;
    _poll = Timer.periodic(const Duration(seconds: 2), (t) async {
      tentatives++;
      final result = await ref.read(getStatutPaiementUseCaseProvider).call(reference);
      if (!mounted) return;
      result.fold((_) {}, (p) {
        setState(() => _paiement = p);
        if (!p.estEnAttente) {
          t.cancel();
          setState(() => _enCours = false);
          if (p.estReussi) {
            ref.invalidate(recettesProvider);
            ref.invalidate(cotisationsProvider);
            ref.invalidate(soldeProvider);
            ref.invalidate(operationsProvider);
          }
        }
      });
      if (tentatives >= 20) {
        t.cancel();
        if (mounted) setState(() => _enCours = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_telInit) {
      final tel = ref.read(profilProvider).valueOrNull?.telephone;
      if (tel != null && tel.isNotEmpty) {
        _telephone.text = tel;
        _telInit = true;
      }
    }

    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + keyboard + bottomSafe),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'Payer',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                  letterSpacing: -0.4),
            ),
          ),
          if (_paiement != null) _vueStatut() else _vueFormulaire(),
        ],
      ),
    );
  }

  // ── Formulaire ──────────────────────────────────────────────────────────
  Widget _vueFormulaire() {
    final payables = _payables();
    final cible =
        payables.where((p) => p.cle == _cibleCle).cast<_Payable?>().firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormCard(
          icon: Icons.receipt_long_outlined,
          title: 'Recette / cotisation',
          child: _LabeledField(
            label: 'À payer',
            isRequired: true,
            child: payables.isEmpty
                ? const Text('Aucune recette ou cotisation à payer.',
                    style: TextStyle(color: AppColors.hint))
                : DropdownButtonFormField<String>(
                    initialValue: _cibleCle,
                    isExpanded: true,
                    decoration: _deco('Sélectionner'),
                    items: payables
                        .map((p) => DropdownMenuItem(
                              value: p.cle,
                              child: Text('${p.label} • ${Fmt.money(p.montant)}',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: _enCours
                        ? null
                        : (v) => setState(() => _cibleCle = v),
                  ),
          ),
        ),
        _FormCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Portefeuille',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CanalPaiement.values.map((c) {
              return ChoiceChip(
                label: Text(c.label),
                selected: c == _canal,
                onSelected: _enCours ? null : (_) => setState(() => _canal = c),
              );
            }).toList(),
          ),
        ),
        _FormCard(
          icon: Icons.phone_iphone_outlined,
          title: 'Numéro Mobile Money',
          child: _LabeledField(
            label: 'Numéro',
            isRequired: true,
            child: TextField(
              controller: _telephone,
              keyboardType: TextInputType.phone,
              decoration: _deco('Ex. 0707070707'),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: (_enCours || cible == null) ? null : () => _payer(cible),
            icon: _enCours
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.lock_rounded),
            label: Text(cible == null ? 'Payer' : 'Payer ${Fmt.money(cible.montant)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // ── Suivi du statut ─────────────────────────────────────────────────────
  Widget _vueStatut() {
    final p = _paiement!;
    final (IconData icone, Color couleur, String titre, String sous) =
        p.estReussi
            ? (
                Icons.check_circle_rounded,
                AppColors.success,
                'Paiement réussi',
                'Votre règlement a bien été pris en compte.'
              )
            : p.estEchoue
                ? (
                    Icons.cancel_rounded,
                    AppColors.error,
                    'Paiement échoué',
                    p.messageErreur ?? 'Le paiement n\'a pas abouti.'
                  )
                : (
                    Icons.hourglass_top_rounded,
                    AppColors.warning,
                    'En attente de confirmation',
                    'Validez la demande sur votre téléphone (${p.canal ?? ''}).'
                  );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(icone, size: 72, color: couleur),
          const SizedBox(height: 14),
          Text(titre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(sous,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Text(Fmt.money(p.montant),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (p.estEnAttente)
            const CircularProgressIndicator()
          else
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(p.estReussi),
                child: const Text('Terminer'),
              ),
            ),
          if (p.estEchoue)
            TextButton(
              onPressed: () => setState(() {
                _paiement = null;
                _enCours = false;
              }),
              child: const Text('Réessayer'),
            ),
        ],
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.hint, fontSize: 15),
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}

// ── Carte de section (style « Encaisser ») ────────────────────────────────────

class _FormCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _FormCard(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                    letterSpacing: -0.2)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final Widget child;
  const _LabeledField(
      {required this.label, this.isRequired = false, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label)),
          if (isRequired) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ]),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
