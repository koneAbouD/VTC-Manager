import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/encaissement_cotisation.dart';
import '../../domain/entities/ligne_cotisation.dart';
import '../providers/ligne_cotisation_provider.dart';
import '../../../../core/widgets/app_header.dart';

class EncaissementCotisationFormPage extends ConsumerStatefulWidget {
  final LigneCotisation ligne;
  const EncaissementCotisationFormPage({super.key, required this.ligne});

  @override
  ConsumerState<EncaissementCotisationFormPage> createState() => _State();
}

class _State extends ConsumerState<EncaissementCotisationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  ModePaiementCotisation _mode = ModePaiementCotisation.especes;
  DateTime _date = DateTime.now();
  bool _loading = false;

  double get _restant =>
      widget.ligne.montantRestant ?? (widget.ligne.montantDu - widget.ligne.montantEncaisse);

  @override
  void dispose() {
    _montantCtrl.dispose(); _refCtrl.dispose(); _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    return Scaffold(
      appBar: AppHeader(title: 'Encaisser — ${widget.ligne.nomCotisation}'),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text('Restant : ${fmt.format(_restant)}', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _montantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Montant *', suffixText: 'XOF', border: OutlineInputBorder()),
            validator: (v) {
              final val = double.tryParse(v?.replaceAll(',', '.') ?? '');
              if (val == null || val <= 0) return 'Montant invalide';
              if (val > _restant) return 'Dépasse le restant (${fmt.format(_restant)})';
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ModePaiementCotisation>(
            value: _mode,
            decoration: const InputDecoration(labelText: "Mode d'encaissement *", border: OutlineInputBorder()),
            items: ModePaiementCotisation.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label))).toList(),
            onChanged: (v) => setState(() => _mode = v!),
          ),
          if (_mode == ModePaiementCotisation.mobileMoney) ...[
            const SizedBox(height: 16),
            TextFormField(controller: _refCtrl,
                decoration: const InputDecoration(labelText: 'Référence Mobile Money', border: OutlineInputBorder())),
          ],
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Date d'encaissement"),
            subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final p = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
              if (p != null) setState(() => _date = p);
            },
          ),
          const Divider(),
          TextFormField(controller: _commentCtrl, maxLines: 2,
              decoration: const InputDecoration(labelText: 'Commentaire', border: OutlineInputBorder())),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Encaisser'),
          ),
        ]),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final enc = EncaissementCotisation(
      ligneCotisationId: widget.ligne.id!,
      montant: double.parse(_montantCtrl.text.replaceAll(',', '.')),
      modeEncaissement: _mode,
      dateEncaissement: _date,
      reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      commentaire: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
    );

    final error = await ref.read(ligneCotisationNotifierProvider.notifier)
        .createEncaissement(widget.ligne.id!, enc);

    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      Navigator.pop(context, true);
    }
  }
}
