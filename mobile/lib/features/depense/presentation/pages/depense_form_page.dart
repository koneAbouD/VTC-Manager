import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/depense.dart';
import '../providers/depense_provider.dart';
import '../../../../core/widgets/app_header.dart';

enum _ToastType { success, error, warning, info }

void _appToast(
  BuildContext context,
  String message, {
  _ToastType type = _ToastType.success,
  Duration? duration,
}) {
  final (Color bg, IconData icon) = switch (type) {
    _ToastType.success => (const Color(0xFF1B5E20), Icons.check_circle_outline_rounded),
    _ToastType.error   => (const Color(0xFFB71C1C), Icons.error_outline_rounded),
    _ToastType.warning => (const Color(0xFFE65100), Icons.warning_amber_rounded),
    _ToastType.info    => (const Color(0xFF1A237E), Icons.info_outline_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
        ),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration ??
          (type == _ToastType.error || type == _ToastType.warning
              ? const Duration(seconds: 4)
              : const Duration(seconds: 2)),
    ));
}

class DepenseFormPage extends ConsumerStatefulWidget {
  final Depense? initial;
  const DepenseFormPage({super.key, this.initial});

  @override
  ConsumerState<DepenseFormPage> createState() => _DepenseFormPageState();
}

class _DepenseFormPageState extends ConsumerState<DepenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montant;
  late final TextEditingController _description;
  DateTime? _date;
  bool _loading = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _montant =
        TextEditingController(text: d?.montant.toStringAsFixed(2) ?? '');
    _description = TextEditingController(text: d?.description ?? '');
    _date = d?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _montant.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      _appToast(context, 'Veuillez sélectionner une date', type: _ToastType.warning);
      return;
    }
    setState(() => _loading = true);

    final depense = Depense(
      id: widget.initial?.id,
      date: _date!,
      montant: double.parse(_montant.text.replaceAll(',', '.')),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      categorieId: widget.initial?.categorieId,
      vehiculeId: widget.initial?.vehiculeId,
      chauffeurId: widget.initial?.chauffeurId,
    );

    final notifier = ref.read(depenseNotifierProvider.notifier);
    final error = _isEditing
        ? await notifier.updateDepense(widget.initial!.id!, depense)
        : await notifier.createDepense(depense);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      _appToast(context, error, type: _ToastType.error);
    } else {
      _appToast(context, _isEditing ? 'Dépense modifiée !' : 'Dépense créée !');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: _isEditing ? 'Modifier dépense' : 'Nouvelle dépense'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Date picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.edit_calendar, size: 18),
                ),
                child: Text(
                  _date != null
                      ? '${_date!.day.toString().padLeft(2, '0')}/'
                          '${_date!.month.toString().padLeft(2, '0')}/'
                          '${_date!.year}'
                      : 'Sélectionner une date',
                  style: TextStyle(color: _date != null ? null : Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _montant,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requis';
                if (double.tryParse(v.replaceAll(',', '.')) == null) {
                  return 'Montant invalide';
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Montant *',
                prefixIcon: Icon(Icons.money_off),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
