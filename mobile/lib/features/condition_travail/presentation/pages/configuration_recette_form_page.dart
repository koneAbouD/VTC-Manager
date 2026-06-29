import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/configuration_recette.dart';
import '../../domain/enums/frequence_versement.dart';
import '../../domain/enums/jour_semaine.dart';
import '../../domain/enums/mode_encaissement.dart';
import '../../domain/enums/type_recette_configuration.dart';
import '../providers/configuration_recette_provider.dart';
import '../../../vehicule/domain/entities/vehicule.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_header.dart';

// ── Toast helpers ──────────────────────────────────────────────────────────────
enum _ToastType { success, error, warning, info }

void _appToast(BuildContext context, String message,
    {_ToastType type = _ToastType.success, Duration? duration}) {
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
        Expanded(child: Text(message,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white))),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration ?? (type == _ToastType.error || type == _ToastType.warning
          ? const Duration(seconds: 4) : const Duration(seconds: 2)),
    ));
}

class ConfigurationRecetteFormPage extends ConsumerStatefulWidget {
  final Vehicule vehicule;
  final ConfigurationRecette? initialConfiguration;
  final bool jourSalaireActif;

  const ConfigurationRecetteFormPage({
    super.key,
    required this.vehicule,
    this.initialConfiguration,
    this.jourSalaireActif = true,
  });

  @override
  ConsumerState<ConfigurationRecetteFormPage> createState() =>
      _ConfigurationRecetteFormPageState();
}

class _ConfigurationRecetteFormPageState
    extends ConsumerState<ConfigurationRecetteFormPage> {
  late ModeEncaissement _modeEncaissement;
  late TypeRecetteConfiguration _typeRecette;
  late FrequenceVersement _frequenceVersement;
  late JourSemaine _jourVersement;
  late TimeOfDay _heureLimiteVersement;
  late TextEditingController _objectifController;
  late TextEditingController _jourSalaireController;
  late ConfigurationRecette _baseConfiguration;
  bool _saving = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _baseConfiguration = widget.initialConfiguration ??
        ConfigurationRecette.defaultForVehicule(widget.vehicule.id ?? 0);
    _modeEncaissement = _baseConfiguration.modeEncaissement;
    _typeRecette = _baseConfiguration.typeRecette;
    _frequenceVersement = _baseConfiguration.frequenceVersement;
    _jourVersement =
        _baseConfiguration.jourVersement ?? JourSemaine.dimanche;
    _heureLimiteVersement = _baseConfiguration.heureLimiteVersement;
    _objectifController = TextEditingController(
      text: _baseConfiguration.montantObjectifParChauffeur == null
          ? ''
          : _formatAmountInput(
              _baseConfiguration.montantObjectifParChauffeur!),
    );
    _jourSalaireController = TextEditingController(
      text: _baseConfiguration.montantJourSalaire == null
          ? ''
          : _formatAmountInput(_baseConfiguration.montantJourSalaire!),
    );
  }

  @override
  void dispose() {
    _objectifController.dispose();
    _jourSalaireController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: const AppHeader(title: 'Configuration recette'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            AppErrorBanner(
              message: _submitError!,
              onClose: () => setState(() => _submitError = null),
            ),
            const SizedBox(height: 8),
          ],
          const Text(
            'Configurer les\nrecettes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
          ),
          const SizedBox(height: 24),

          // ── Moyen d'encaissement ──────────────────────────────────────────
          _sectionLabel("Définir le moyen d'encaissement"),
          const SizedBox(height: 10),
          Row(
            children: ModeEncaissement.values.map((mode) {
              final selected = _modeEncaissement == mode;
              return Expanded(
                child: GestureDetector(
                  onTap: _saving
                      ? null
                      : () => setState(() => _modeEncaissement = mode),
                  child: Row(
                    children: [
                      Radio<ModeEncaissement>(
                        value: mode,
                        groupValue: _modeEncaissement,
                        activeColor: const Color(0xFF43A047),
                        visualDensity: VisualDensity.compact,
                        onChanged: _saving
                            ? null
                            : (v) =>
                                setState(() => _modeEncaissement = v!),
                      ),
                      Flexible(
                        child: Text(
                          mode.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
                                ? const Color(0xFF43A047)
                                : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── Type de recette ───────────────────────────────────────────────
          _sectionLabel('Définir le type de recette'),
          const SizedBox(height: 8),
          _dropdownField<TypeRecetteConfiguration>(
            value: _typeRecette,
            items: TypeRecetteConfiguration.values,
            labelBuilder: (v) => v.label,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _typeRecette = v;
                if (v == TypeRecetteConfiguration.montantReel) {
                  _objectifController.clear();
                }
              });
            },
          ),
          const SizedBox(height: 24),

          // ── Objectif de recette ───────────────────────────────────────────
          const Text(
            'OBJECTIF DE RECETTE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 16),

          _sectionLabel('Fréquence de versement de recette'),
          const SizedBox(height: 8),
          _dropdownField<FrequenceVersement>(
            value: _frequenceVersement,
            items: FrequenceVersement.values,
            labelBuilder: (v) => v.label,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _frequenceVersement = v);
            },
          ),
          const SizedBox(height: 16),

          // Jour de versement (uniquement si Hebdomadaire)
          if (_frequenceVersement == FrequenceVersement.hebdomadaire) ...[
            _sectionLabel('Jour de versement de la recette'),
            const SizedBox(height: 8),
            _dropdownField<JourSemaine>(
              value: _jourVersement,
              items: JourSemaine.values,
              labelBuilder: (v) => 'Chaque ${v.label}',
              onChanged: (v) {
                if (v == null) return;
                setState(() => _jourVersement = v);
              },
            ),
            const SizedBox(height: 16),
          ],

          _sectionLabel(
              'Heure de versement de la recette au plus tard'),
          const SizedBox(height: 8),
          _timeField(
            value: _formatTime(_heureLimiteVersement),
            onTap: _saving ? null : _pickTime,
          ),

          if (_typeRecette == TypeRecetteConfiguration.montantFixe) ...[
            const SizedBox(height: 16),
            _moneyField(
              controller: _objectifController,
              label:
                  'Objectif de recette ${_frequenceVersement.label} par chauffeur (XOF) *',
              hint: 'Montant',
              required: true,
            ),
          ],
          if (widget.jourSalaireActif) ...[
            const SizedBox(height: 16),
            _moneyField(
              controller: _jourSalaireController,
              label: 'Recette à payer le jour de salaire',
              hint: '0 (XOF) — optionnel',
            ),
          ],
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Mettre à jour',
                      style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
      );

  Widget _dropdownField<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(labelBuilder(item)),
                  ))
              .toList(),
          onChanged: _saving ? null : onChanged,
        ),
      ),
    );
  }

  Widget _timeField({
    required String value,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 16)),
            ),
            Icon(Icons.access_time_outlined,
                size: 20, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
            children: required
                ? const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: !_saving,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFE4E7EC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFE4E7EC)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _heureLimiteVersement,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    setState(() => _heureLimiteVersement = picked);
  }

  Future<void> _save() async {
    setState(() => _submitError = null);
    if (widget.vehicule.id == null) {
      _showError(
          'Le véhicule doit être enregistré avant de configurer les recettes.');
      return;
    }

    final objectif = _parseMoney(_objectifController.text);

    if (_typeRecette == TypeRecetteConfiguration.montantFixe &&
        (objectif == null || objectif <= 0)) {
      _showError(
          "Renseignez l'objectif de recette par chauffeur pour un montant fixe.");
      return;
    }

    if (_frequenceVersement == FrequenceVersement.hebdomadaire) {
      // jourVersement déjà défini (défaut : dimanche)
    }

    final montantJourSalaire = _parseMoney(_jourSalaireController.text);
    if (montantJourSalaire != null && montantJourSalaire < 0) {
      _showError('Le montant du jour de salaire ne peut pas être négatif.');
      return;
    }

    setState(() => _saving = true);

    final configuration = _baseConfiguration.copyWith(
      id: widget.initialConfiguration?.id,
      vehiculeId: widget.vehicule.id!,
      modeEncaissement: _modeEncaissement,
      typeRecette: _typeRecette,
      frequenceVersement: _frequenceVersement,
      jourVersement: _frequenceVersement == FrequenceVersement.hebdomadaire
          ? _jourVersement
          : null,
      clearJourVersement:
          _frequenceVersement != FrequenceVersement.hebdomadaire,
      heureLimiteVersement: _heureLimiteVersement,
      montantObjectifParChauffeur: objectif,
      clearMontantObjectifParChauffeur:
          _typeRecette == TypeRecetteConfiguration.montantReel,
      montantJourSalaire: montantJourSalaire,
      clearMontantJourSalaire: _jourSalaireController.text.trim().isEmpty,
      cotisations: _baseConfiguration.cotisationsTriees,
    );

    final error = await ref
        .read(configurationRecetteControllerProvider)
        .saveConfiguration(widget.vehicule.id!, configuration);

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      _showError(error);
      return;
    }

    _appToast(context, 'Configuration de recette enregistrée.');
    Navigator.pop(context);
  }

  double? _parseMoney(String value) {
    final s = value.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  String _formatTime(TimeOfDay value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatAmountInput(double value) {
    final rounded =
        value == value.roundToDouble() ? value.toInt() : value;
    return rounded.toString();
  }

  void _showError(String message) {
    setState(() => _submitError = message);
    _appToast(context, message, type: _ToastType.error);
  }
}
