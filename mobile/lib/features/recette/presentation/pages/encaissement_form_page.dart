import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/encaissement.dart';
import '../../domain/entities/ligne_recette.dart';
import '../providers/ligne_recette_provider.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_error_banner.dart';

class EncaissementFormPage extends ConsumerStatefulWidget {
  final LigneRecette ligne;

  const EncaissementFormPage({super.key, required this.ligne});

  @override
  ConsumerState<EncaissementFormPage> createState() => _EncaissementFormPageState();
}

class _EncaissementFormPageState extends ConsumerState<EncaissementFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _commentaireCtrl = TextEditingController();

  ModeEncaissement _mode = ModeEncaissement.especes;
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

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

    return Scaffold(
      appBar: const AppHeader(title: 'Encaissement'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              AppErrorBanner(
                message: _error!,
                onClose: () => setState(() => _error = null),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.ligne.montantRestant != null)
              _InfoBanner(
                'Montant restant : ${fmt.format(widget.ligne.montantRestant!)}',
                color: Colors.blue.shade50,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _montantCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant *',
                suffixText: 'XOF',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final val = double.tryParse(v?.replaceAll(',', '.') ?? '');
                if (val == null || val <= 0) return 'Montant invalide';
                if (widget.ligne.montantRestant != null && val > widget.ligne.montantRestant!) {
                  return 'Dépasse le montant restant (${fmt.format(widget.ligne.montantRestant!)})';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ModeEncaissement>(
              initialValue: _mode,
              decoration: const InputDecoration(
                labelText: 'Mode d\'encaissement *',
                border: OutlineInputBorder(),
              ),
              items: ModeEncaissement.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                  .toList(),
              onChanged: (v) => setState(() {
                _mode = v!;
                _error = null;
              }),
            ),
            if (_mode == ModeEncaissement.mobileMoney) ...[
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
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Encaisser'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final encaissement = Encaissement(
      ligneRecetteId: widget.ligne.id!,
      montant: double.parse(_montantCtrl.text.replaceAll(',', '.')),
      modeEncaissement: _mode,
      dateEncaissement: _date,
      reference: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
      commentaire: _commentaireCtrl.text.trim().isEmpty ? null : _commentaireCtrl.text.trim(),
    );

    final error = await ref
        .read(ligneRecetteNotifierProvider.notifier)
        .createEncaissement(widget.ligne.id!, encaissement);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });

    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: const Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
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
      child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}
