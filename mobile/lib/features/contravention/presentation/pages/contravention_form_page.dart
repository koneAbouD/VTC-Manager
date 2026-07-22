import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../../core/widgets/filtre_vehicule_chauffeur_dialog.dart';
import '../../../chauffeur/domain/entities/chauffeur.dart';
import '../../../chauffeur/presentation/providers/chauffeur_provider.dart';
import '../../../chauffeur/presentation/providers/chauffeur_state.dart';
import '../../../vehicule/domain/entities/vehicule.dart';
import '../../../vehicule/presentation/providers/vehicule_provider.dart';
import '../../../vehicule/presentation/providers/vehicule_state.dart';
import '../../domain/entities/contravention.dart';
import '../providers/contravention_provider.dart';

enum _ToastType { success, error, warning, info }

void _appToast(
  BuildContext context,
  String message, {
  _ToastType type = _ToastType.success,
}) {
  final (Color bg, IconData icon) = switch (type) {
    _ToastType.success => (AppColors.success, Icons.check_circle_outline_rounded),
    _ToastType.error   => (AppColors.error, Icons.error_outline_rounded),
    _ToastType.warning => (AppColors.warning, Icons.warning_amber_rounded),
    _ToastType.info    => (AppColors.info, Icons.info_outline_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
        ),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: type == _ToastType.error || type == _ToastType.warning
          ? const Duration(seconds: 4)
          : const Duration(seconds: 2),
    ));
}

/// Formulaire premium de saisie / édition d'une contravention (tous les champs,
/// y compris les champs propres aux contraventions de l'État).
class ContraventionFormPage extends ConsumerStatefulWidget {
  final Contravention? initial;
  const ContraventionFormPage({super.key, this.initial});

  @override
  ConsumerState<ContraventionFormPage> createState() =>
      _ContraventionFormPageState();
}

class _ContraventionFormPageState extends ConsumerState<ContraventionFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _numero;
  late final TextEditingController _code;
  late final TextEditingController _typeInfraction;
  late final TextEditingController _vitesse;
  late final TextEditingController _lieu;
  late final TextEditingController _description;
  late final TextEditingController _montant;
  late final TextEditingController _cotisation;
  late final TextEditingController _montantPaye;

  DateTime? _dateInfraction;
  TimeOfDay? _heure;
  DateTime? _datePaiement;

  int? _vehiculeId;
  String? _vehiculeLabel;
  int? _chauffeurId;
  String? _chauffeurLabel;

  bool _loading = false;
  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _numero = TextEditingController(text: c?.numeroContravention ?? '');
    _code = TextEditingController(text: c?.codeInfraction ?? '');
    _typeInfraction = TextEditingController(text: c?.typeInfraction ?? '');
    _vitesse =
        TextEditingController(text: c?.vitesseRelevee?.toString() ?? '');
    _lieu = TextEditingController(text: c?.lieu ?? '');
    _description = TextEditingController(text: c?.description ?? '');
    _montant = TextEditingController(
        text: c != null ? _trimNum(c.montant) : '');
    _cotisation = TextEditingController(
        text: c?.cotisation != null ? _trimNum(c!.cotisation!) : '');
    _montantPaye = TextEditingController(
        text: c?.montantPaye != null ? _trimNum(c!.montantPaye!) : '');
    _dateInfraction = c?.dateInfraction ?? DateTime.now();
    _datePaiement = c?.datePaiement;
    _heure = _parseHeure(c?.heureInfraction);
    _vehiculeId = c?.vehiculeId;
    _vehiculeLabel = c?.vehiculeNom;
    _chauffeurId = c?.chauffeurId;
    _chauffeurLabel = c?.chauffeurNom;
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static TimeOfDay? _parseHeure(String? h) {
    if (h == null || h.length < 4) return null;
    final parts = h.split(':');
    if (parts.length < 2) return null;
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null) return null;
    return TimeOfDay(hour: hh, minute: mm);
  }

  @override
  void dispose() {
    for (final c in [
      _numero, _code, _typeInfraction, _vitesse, _lieu,
      _description, _montant, _cotisation, _montantPaye
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Pickers ─────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: _dateInfraction ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      ),
    );
    if (picked != null) setState(() => _dateInfraction = picked);
  }

  Future<void> _pickHeure() async {
    final picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (_) => HeurePickerDialog(initialTime: _heure ?? TimeOfDay.now()),
    );
    if (picked != null) setState(() => _heure = picked);
  }

  Future<void> _pickDatePaiement() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: _datePaiement ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      ),
    );
    if (picked != null) setState(() => _datePaiement = picked);
  }

  /// Véhicule actuellement lié, retrouvé dans la liste chargée (pour pré-cocher
  /// le sélecteur lors d'une modification du lien).
  Vehicule? _currentVehicule() {
    if (_vehiculeId == null) return null;
    final st = ref.read(vehiculeNotifierProvider);
    final list = st is VehiculeLoaded ? st.vehicules : const <Vehicule>[];
    for (final v in list) {
      if (v.id == _vehiculeId) return v;
    }
    return null;
  }

  Chauffeur? _currentChauffeur() {
    if (_chauffeurId == null) return null;
    final st = ref.read(chauffeurNotifierProvider);
    final list = st is ChauffeurLoaded ? st.chauffeurs : const <Chauffeur>[];
    for (final c in list) {
      if (c.id == _chauffeurId) return c;
    }
    return null;
  }

  Future<void> _pickVehiculeChauffeur() async {
    final res = await showFiltreVehiculeChauffeurDialog(
      context,
      vehiculeInitial: _currentVehicule(),
      chauffeurInitial: _currentChauffeur(),
    );
    if (res == null) return;
    setState(() {
      _vehiculeId = res.vehicule?.id;
      _vehiculeLabel = res.vehicule?.immatriculation;
      _chauffeurId = res.chauffeur?.id;
      _chauffeurLabel = res.chauffeur != null
          ? '${res.chauffeur!.prenom} ${res.chauffeur!.nom}'.trim()
          : null;
    });
  }

  // ── Enregistrement ──────────────────────────────────────────────────────

  double? _parseMontant(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.tryParse(c.text.replaceAll(',', '.'));

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vehiculeId == null) {
      _appToast(context, 'Sélectionnez un véhicule',
          type: _ToastType.warning);
      return;
    }
    if (_dateInfraction == null) {
      _appToast(context, "Sélectionnez une date d'infraction",
          type: _ToastType.warning);
      return;
    }
    setState(() => _loading = true);

    final heureStr = _heure != null
        ? '${_heure!.hour.toString().padLeft(2, '0')}:'
            '${_heure!.minute.toString().padLeft(2, '0')}:00'
        : null;

    final contravention = Contravention(
      id: widget.initial?.id,
      dateInfraction: _dateInfraction!,
      heureInfraction: heureStr,
      numeroContravention: _text(_numero),
      codeInfraction: _text(_code),
      typeInfraction: _text(_typeInfraction),
      vitesseRelevee:
          _vitesse.text.trim().isEmpty ? null : int.tryParse(_vitesse.text.trim()),
      lieu: _text(_lieu),
      description: _text(_description),
      montant: double.parse(_montant.text.replaceAll(',', '.')),
      cotisation: _parseMontant(_cotisation),
      montantPaye: _parseMontant(_montantPaye),
      datePaiement: _datePaiement,
      chauffeurId: _chauffeurId,
      vehiculeId: _vehiculeId,
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
      _appToast(context,
          _isEditing ? 'Contravention modifiée' : 'Contravention créée');
      Navigator.pop(context, true);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
          title: _isEditing ? 'Modifier la contravention' : 'Nouvelle contravention'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _section('Véhicule et chauffeur', Icons.directions_car_outlined, [
              _selector(),
            ], obligatoire: true),
            _section('Infraction', Icons.gavel_outlined, [
              Row(children: [
                Expanded(child: _dateTile()),
                const SizedBox(width: 12),
                Expanded(child: _heureTile()),
              ]),
              const SizedBox(height: 14),
              _labeled('Numéro de contravention',
                  _input(_numero, 'C0000…', icon: Icons.tag)),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: _labeled('Code',
                        _input(_code, '046', icon: Icons.qr_code_2))),
                const SizedBox(width: 12),
                Expanded(
                    child: _labeled(
                        'Vitesse (km/h)',
                        _input(_vitesse, '90',
                            icon: Icons.speed_outlined,
                            number: true, digitsOnly: true))),
              ]),
              const SizedBox(height: 14),
              _labeled("Type d'infraction",
                  _input(_typeInfraction, 'Excès de vitesse', icon: Icons.category_outlined)),
              const SizedBox(height: 14),
              _labeled('Lieu',
                  _input(_lieu, "Lieu de l'infraction", icon: Icons.location_on_outlined)),
              const SizedBox(height: 14),
              _labeled('Description',
                  _input(_description, 'Précisions…',
                      icon: Icons.notes_outlined, maxLines: 3)),
            ]),
            _section('Montants', Icons.payments_outlined, [
              _labeled('Montant *',
                  _input(_montant, '0', icon: Icons.attach_money,
                      number: true, validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requis';
                if (double.tryParse(v.replaceAll(',', '.')) == null) {
                  return 'Montant invalide';
                }
                return null;
              })),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: _labeled('Cotisation',
                        _input(_cotisation, '0',
                            icon: Icons.savings_outlined, number: true))),
                const SizedBox(width: 12),
                Expanded(
                    child: _labeled('Montant payé',
                        _input(_montantPaye, '0',
                            icon: Icons.price_check, number: true))),
              ]),
              const SizedBox(height: 14),
              _labeled('Date de paiement', _datePaiementTile()),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _loading
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(_isEditing ? 'Enregistrer' : 'Créer la contravention',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Composants ──────────────────────────────────────────────────────────

  Widget _section(String title, IconData icon, List<Widget> children,
      {bool obligatoire = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
            RichText(
              text: TextSpan(
                text: title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark),
                children: obligatoire
                    ? const [
                        TextSpan(
                            text: ' *',
                            style: TextStyle(color: AppColors.error))
                      ]
                    : null,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _labeled(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.label)),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String hint, {
    IconData? icon,
    bool number = false,
    bool digitsOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      maxLines: maxLines,
      keyboardType: number
          ? TextInputType.numberWithOptions(decimal: !digitsOnly)
          : TextInputType.text,
      inputFormatters:
          digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: const TextStyle(fontSize: 14, color: AppColors.dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
        filled: true,
        fillColor: AppColors.fieldFill,
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: AppColors.hint)
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4)),
      ),
    );
  }

  Widget _selector() {
    final vide = _vehiculeId == null && _chauffeurId == null;
    return InkWell(
      onTap: _pickVehiculeChauffeur,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.directions_car_outlined,
              size: 18, color: vide ? AppColors.hint : AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: vide
                ? const Text('Sélectionner véhicule et chauffeur',
                    style: TextStyle(fontSize: 14, color: AppColors.hint))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_vehiculeLabel ?? 'Véhicule non défini',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.dark)),
                      if (_chauffeurLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(_chauffeurLabel!,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.label)),
                        ),
                    ],
                  ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.hint),
        ]),
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String value,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: filled ? AppColors.primary : AppColors.hint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    color: filled ? AppColors.dark : AppColors.hint)),
          ),
        ]),
      ),
    );
  }

  Widget _dateTile() => _labeled(
        "Date *",
        _pickerTile(
          icon: Icons.calendar_today_outlined,
          value: _dateInfraction != null
              ? _fmtDate(_dateInfraction!)
              : 'Choisir',
          filled: _dateInfraction != null,
          onTap: _pickDate,
        ),
      );

  Widget _heureTile() => _labeled(
        'Heure',
        _pickerTile(
          icon: Icons.access_time,
          value: _heure != null ? _heure!.format(context) : 'Choisir',
          filled: _heure != null,
          onTap: _pickHeure,
        ),
      );

  Widget _datePaiementTile() => _pickerTile(
        icon: Icons.event_available_outlined,
        value: _datePaiement != null ? _fmtDate(_datePaiement!) : 'Non payé',
        filled: _datePaiement != null,
        onTap: _pickDatePaiement,
      );

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
