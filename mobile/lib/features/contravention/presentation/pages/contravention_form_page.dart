import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/contravention.dart';
import '../providers/contravention_provider.dart';
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

class ContraventionFormPage extends ConsumerStatefulWidget {
  final Contravention? initial;
  const ContraventionFormPage({super.key, this.initial});

  @override
  ConsumerState<ContraventionFormPage> createState() =>
      _ContraventionFormPageState();
}

class _ContraventionFormPageState
    extends ConsumerState<ContraventionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _typeInfraction;
  late final TextEditingController _lieu;
  late final TextEditingController _description;
  late final TextEditingController _montant;
  late final TextEditingController _cotisation;
  DateTime? _dateInfraction;
  bool _loading = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _typeInfraction = TextEditingController(text: c?.typeInfraction ?? '');
    _lieu = TextEditingController(text: c?.lieu ?? '');
    _description = TextEditingController(text: c?.description ?? '');
    _montant =
        TextEditingController(text: c?.montant.toStringAsFixed(2) ?? '');
    _cotisation = TextEditingController(
        text: c?.cotisation?.toStringAsFixed(2) ?? '');
    _dateInfraction = c?.dateInfraction ?? DateTime.now();
  }

  @override
  void dispose() {
    _typeInfraction.dispose();
    _lieu.dispose();
    _description.dispose();
    _montant.dispose();
    _cotisation.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateInfraction ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateInfraction = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateInfraction == null) {
      _appToast(context, 'Veuillez sélectionner une date', type: _ToastType.warning);
      return;
    }
    setState(() => _loading = true);

    final contravention = Contravention(
      id: widget.initial?.id,
      dateInfraction: _dateInfraction!,
      typeInfraction: _typeInfraction.text.trim().isEmpty
          ? null
          : _typeInfraction.text.trim(),
      lieu: _lieu.text.trim().isEmpty ? null : _lieu.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      montant: double.parse(_montant.text.replaceAll(',', '.')),
      cotisation: _cotisation.text.trim().isEmpty
          ? null
          : double.tryParse(_cotisation.text.replaceAll(',', '.')),
      chauffeurId: widget.initial?.chauffeurId,
      vehiculeId: widget.initial?.vehiculeId,
    );

    final notifier = ref.read(contraventionNotifierProvider.notifier);
    final error = _isEditing
        ? await notifier.updateContravention(widget.initial!.id!, contravention)
        : await notifier.createContravention(contravention);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      _appToast(context, error, type: _ToastType.error);
    } else {
      _appToast(context, _isEditing ? 'Contravention modifiée !' : 'Contravention créée !');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: _isEditing ? 'Modifier contravention' : 'Nouvelle contravention'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Date infraction
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date d\'infraction *',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.edit_calendar, size: 18),
                ),
                child: Text(
                  _dateInfraction != null
                      ? '${_dateInfraction!.day.toString().padLeft(2, '0')}/'
                          '${_dateInfraction!.month.toString().padLeft(2, '0')}/'
                          '${_dateInfraction!.year}'
                      : 'Sélectionner une date',
                  style: TextStyle(
                      color: _dateInfraction != null ? null : Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _field(_typeInfraction, 'Type d\'infraction', Icons.gavel),
            const SizedBox(height: 14),
            _field(_lieu, 'Lieu', Icons.location_on),
            const SizedBox(height: 14),
            _field(_description, 'Description', Icons.notes),
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
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cotisation,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cotisation',
                prefixIcon: Icon(Icons.savings),
                border: OutlineInputBorder(),
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
