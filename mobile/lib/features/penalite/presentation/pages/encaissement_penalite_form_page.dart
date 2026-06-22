import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/ligne_penalite.dart';
import '../providers/penalite_provider.dart';
import '../../../../core/widgets/app_header.dart';

class EncaissementPenaliteFormPage extends ConsumerStatefulWidget {
  final LignePenalite ligne;
  const EncaissementPenaliteFormPage({super.key, required this.ligne});

  @override
  ConsumerState<EncaissementPenaliteFormPage> createState() =>
      _EncaissementPenaliteFormPageState();
}

class _EncaissementPenaliteFormPageState
    extends ConsumerState<EncaissementPenaliteFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _commentaireCtrl = TextEditingController();

  String _mode = 'ESPECES';
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _montantCtrl.dispose();
    _referenceCtrl.dispose();
    _commentaireCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final restant = widget.ligne.montantRestant;

    return Scaffold(
      appBar: const AppHeader(title: 'Encaissement pénalité'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (restant != null)
              _InfoBanner(
                'Montant restant : ${fmt.format(restant)}',
                color: Colors.orange.shade50,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _montantCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant *',
                suffixText: 'XOF',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final val = double.tryParse(v?.replaceAll(',', '.') ?? '');
                if (val == null || val <= 0) return 'Montant invalide';
                if (restant != null && val > restant) {
                  return 'Dépasse le montant restant (${fmt.format(restant)})';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _mode,
              decoration: const InputDecoration(
                labelText: 'Mode d\'encaissement *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'ESPECES', child: Text('Espèces')),
                DropdownMenuItem(
                    value: 'MOBILE_MONEY', child: Text('Mobile Money')),
              ],
              onChanged: (v) => setState(() => _mode = v!),
            ),
            if (_mode == 'MOBILE_MONEY') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Référence Mobile Money',
                  hintText: 'N° transaction',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date d\'encaissement'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const Divider(),
            TextFormField(
              controller: _commentaireCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Commentaire',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Encaisser'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final error = await ref
        .read(lignePenaliteNotifierProvider.notifier)
        .createEncaissementDetail(widget.ligne.id!, {
      'montant': double.parse(_montantCtrl.text.replaceAll(',', '.')),
      'modeEncaissement': _mode,
      'dateEncaissement': _date,
      if (_referenceCtrl.text.trim().isNotEmpty)
        'reference': _referenceCtrl.text.trim(),
      if (_commentaireCtrl.text.trim().isNotEmpty)
        'commentaire': _commentaireCtrl.text.trim(),
    });

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      Navigator.pop(context, true);
    }
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  final Color color;
  const _InfoBanner(this.message, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child:
          Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}
