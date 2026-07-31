import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/premium_select_field.dart';
import '../../../../screens/finance/finance_refresh.dart';
import '../../domain/entities/facture_partenaire.dart';
import '../providers/partenaire_providers.dart';

/// Règlement d'une facture, total ou partiel.
///
/// Le montant est pré-rempli au restant dû — le cas courant — et plafonné à
/// celui-ci : le serveur refuse tout dépassement, autant ne pas le proposer.
Future<void> showReglementFactureDialog(
  BuildContext context,
  WidgetRef ref,
  FacturePartenaire facture,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReglementSheet(facture: facture),
  );
}

class _ReglementSheet extends ConsumerStatefulWidget {
  final FacturePartenaire facture;
  const _ReglementSheet({required this.facture});

  @override
  ConsumerState<_ReglementSheet> createState() => _ReglementSheetState();
}

class _ReglementSheetState extends ConsumerState<_ReglementSheet> {
  late final TextEditingController _montantCtrl =
      TextEditingController(text: widget.facture.restantDu.toStringAsFixed(0));
  String _mode = 'ESPECES';
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _erreur;

  @override
  void dispose() {
    _montantCtrl.dispose();
    super.dispose();
  }

  double get _montant => double.tryParse(_montantCtrl.text.trim()) ?? 0;

  bool get _valide =>
      _montant > 0 && _montant <= widget.facture.restantDu && !_busy;

  Future<void> _valider() async {
    setState(() {
      _busy = true;
      _erreur = null;
    });
    try {
      await ref.read(partenaireDatasourceProvider).reglerFacture(
            factureId: widget.facture.id!,
            montant: _montant,
            modePaiement: _mode,
            datePaiement: _date,
          );
      if (!mounted) return;
      refreshPartenaires(ref);
      // Un règlement sort de la caisse : tout le module Finances bouge.
      refreshFinances(ref);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Règlement enregistré')),
      );
    } catch (e) {
      if (mounted) setState(() => _erreur = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.facture;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Régler ${f.partenaireNom ?? "la facture"}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark)),
            const SizedBox(height: 4),
            Text(
                '${f.reference ?? ""} · échéance '
                '${DateFormat('dd/MM/yyyy').format(f.dateEcheance)}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.hint)),
            const SizedBox(height: 16),
            _Ligne(
                'Montant de la facture', CurrencyFormatter.format(f.montant)),
            if (f.montantPaye > 0)
              _Ligne('Déjà réglé', CurrencyFormatter.format(f.montantPaye)),
            _Ligne('Restant dû', CurrencyFormatter.format(f.restantDu),
                fort: true),
            const SizedBox(height: 14),
            TextField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Montant réglé',
                suffixText: 'XOF',
                filled: true,
                fillColor: const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorText:
                    _montant > f.restantDu ? 'Au-delà du restant dû' : null,
              ),
            ),
            const SizedBox(height: 12),
            PremiumSelectField<String>(
              value: _mode,
              hint: 'Mode de paiement',
              sheetTitle: 'Mode de paiement',
              options: const [
                SelectOption(value: 'ESPECES', label: 'Espèces'),
                SelectOption(value: 'MOBILE_MONEY', label: 'Mobile money'),
              ],
              onChanged: (v) => setState(() => _mode = v ?? 'ESPECES'),
            ),
            const SizedBox(height: 12),
            _ChampDate(
              date: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 10),
              Text(_erreur!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _valide ? _valider : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer le règlement',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final String libelle;
  final String valeur;
  final bool fort;
  const _Ligne(this.libelle, this.valeur, {this.fort = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(libelle,
                style: TextStyle(
                    fontSize: 13,
                    color: fort ? AppColors.dark : AppColors.label)),
          ),
          Text(valeur,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: fort ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.dark)),
        ],
      ),
    );
  }
}

/// Jour du règlement : rarement autre chose qu'aujourd'hui, mais une saisie en
/// retard doit rester possible.
class _ChampDate extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const _ChampDate({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final choix = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          locale: const Locale('fr', 'FR'),
        );
        if (choix != null) onChanged(choix);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.label),
            const SizedBox(width: 10),
            Text(DateFormat('dd/MM/yyyy').format(date),
                style: const TextStyle(fontSize: 14, color: AppColors.dark)),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.hint),
          ],
        ),
      ),
    );
  }
}
