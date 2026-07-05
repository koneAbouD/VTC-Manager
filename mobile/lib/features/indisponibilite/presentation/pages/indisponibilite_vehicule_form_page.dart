import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../etat_parc/presentation/providers/etat_parc_provider.dart';
import '../../../vehicule/domain/entities/vehicule.dart';
import '../../../vehicule/presentation/pages/vehicule_selector_page.dart';
import '../../../vehicule/presentation/providers/vehicule_provider.dart';
import '../../domain/entities/indisponibilite_vehicule.dart';
import '../providers/indisponibilite_vehicule_provider.dart';

const _motifs = [
  'Accident',
  'Panne',
  'Contrôle technique',
  'Assurance',
  'Administratif',
  'Autre'
];

/// Une immobilisation porte soit sur un jour précis, soit sur une période.
enum _DateMode { jour, periode }

class IndisponibiliteVehiculeFormPage extends ConsumerStatefulWidget {
  final IndisponibiliteVehicule? initial;
  const IndisponibiliteVehiculeFormPage({super.key, this.initial});

  @override
  ConsumerState<IndisponibiliteVehiculeFormPage> createState() => _FormState();
}

class _FormState extends ConsumerState<IndisponibiliteVehiculeFormPage> {
  int? _vehiculeId;
  String? _vehiculeLibelle;
  _DateMode _dateMode = _DateMode.jour;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  String? _motif;
  final _commentaire = TextEditingController();
  bool _loading = false;
  String? _submitError;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _vehiculeId = i.vehiculeId;
      _vehiculeLibelle = i.vehiculeLibelle;
      _dateDebut = i.dateDebut;
      _dateFin = i.dateFin;
      _motif = i.motif;
      _commentaire.text = i.commentaire ?? '';
      final memeJour = i.dateFin == null ||
          (i.dateFin!.year == i.dateDebut.year &&
              i.dateFin!.month == i.dateDebut.month &&
              i.dateFin!.day == i.dateDebut.day);
      _dateMode = memeJour ? _DateMode.jour : _DateMode.periode;
    }
  }

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  Future<Vehicule?> _pickVehicule() async {
    return Navigator.push<Vehicule>(
      context,
      MaterialPageRoute(builder: (_) => const VehiculeSelectorPage()),
    );
  }

  String _libelleDe(Vehicule v) {
    final modele = '${v.marque} ${v.modele}'.trim();
    if (modele.isEmpty) return v.immatriculation;
    return '${v.immatriculation} — $modele';
  }

  Future<void> _pickJour() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = (_dateDebut != null && !_dateDebut!.isBefore(today))
        ? _dateDebut!
        : today;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: initial,
        firstDate: today,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateDebut = picked;
        _dateFin = picked;
      });
    }
  }

  Future<void> _pickPeriode() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initStart = (_dateDebut != null && !_dateDebut!.isBefore(today))
        ? _dateDebut!
        : today;
    final initEnd = (_dateFin != null && !_dateFin!.isBefore(initStart))
        ? _dateFin!
        : initStart;
    final range = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => PeriodePickerDialog(
        initialStart: initStart,
        initialEnd: initEnd,
        firstDate: today,
      ),
    );
    if (range != null) {
      setState(() {
        _dateDebut = range.start;
        _dateFin = range.end;
      });
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (error) setState(() => _submitError = msg);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);
    if (_vehiculeId == null) {
      _toast('Veuillez sélectionner un véhicule.', error: true);
      return;
    }
    if (_dateDebut == null) {
      _toast(
          _dateMode == _DateMode.jour
              ? 'Veuillez choisir le jour.'
              : 'Veuillez choisir la période.',
          error: true);
      return;
    }
    if (_dateMode == _DateMode.jour) _dateFin = _dateDebut;
    if (!_isEdit) {
      final today = DateUtils.dateOnly(DateTime.now());
      if (DateUtils.dateOnly(_dateDebut!).isBefore(today)) {
        _toast(
            "L'immobilisation ne peut pas être définie sur une date ou une période antérieure à aujourd'hui.",
            error: true);
        return;
      }
    }
    if (_dateFin != null && _dateFin!.isBefore(_dateDebut!)) {
      _toast('La date de fin doit être après la date de début.', error: true);
      return;
    }

    setState(() => _loading = true);

    final entity = IndisponibiliteVehicule(
      vehiculeId: _vehiculeId!,
      dateDebut: _dateDebut!,
      dateFin: _dateFin,
      motif: _motif,
      commentaire:
          _commentaire.text.trim().isEmpty ? null : _commentaire.text.trim(),
    );

    final notifier = ref.read(indisponibiliteVehiculeNotifierProvider.notifier);
    final err = _isEdit
        ? await notifier.update(widget.initial!.id!, entity)
        : await notifier.create(entity);

    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      _toast(err, error: true);
    } else {
      // Le statut du véhicule (→ Immobilisé) est recalculé côté backend :
      // rafraîchir la flotte et l'état de parc pour le refléter aussitôt.
      ref.read(vehiculeNotifierProvider.notifier).loadVehicules();
      ref.invalidate(etatParcSummaryProvider);
      _toast(_isEdit ? 'Immobilisation modifiée.' : 'Immobilisation créée.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy', 'fr_FR');
    return Scaffold(
      appBar: AppHeader(
          title: _isEdit
              ? 'Modifier l\'immobilisation'
              : 'Nouvelle immobilisation'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_submitError != null) ...[
            AppErrorBanner(
              message: _submitError!,
              onClose: () => setState(() => _submitError = null),
            ),
            const SizedBox(height: 16),
          ],
          _label(_isEdit
              ? 'Véhicule immobilisé (non modifiable)'
              : 'Véhicule immobilisé *'),
          _SelectorField(
            value: _vehiculeLibelle,
            hint: 'Sélectionner un véhicule',
            icon: Icons.directions_car_outlined,
            enabled: !_isEdit,
            onTap: () async {
              final v = await _pickVehicule();
              if (v != null) {
                setState(() {
                  _vehiculeId = v.id;
                  _vehiculeLibelle = _libelleDe(v);
                });
              }
            },
          ),
          const SizedBox(height: 16),

          _label('Quand ?'),
          Row(
            children: [
              _dateModePill('Jour', _DateMode.jour),
              const SizedBox(width: 8),
              _dateModePill('Période', _DateMode.periode),
            ],
          ),
          const SizedBox(height: 10),
          _SelectorField(
            value: _dateMode == _DateMode.jour
                ? (_dateDebut == null ? null : fmt.format(_dateDebut!))
                : (_dateDebut == null || _dateFin == null
                    ? null
                    : '${fmt.format(_dateDebut!)} → ${fmt.format(_dateFin!)}'),
            hint: _dateMode == _DateMode.jour
                ? 'Choisir le jour'
                : 'Choisir la période',
            icon: _dateMode == _DateMode.jour
                ? Icons.event_outlined
                : Icons.date_range_outlined,
            onTap: _dateMode == _DateMode.jour ? _pickJour : _pickPeriode,
          ),
          const SizedBox(height: 16),

          _label('Motif'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _motifs.map((m) {
              final sel = _motif == m;
              return GestureDetector(
                onTap: () => setState(() => _motif = sel ? null : m),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.headerButton,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    m,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? Colors.white : AppColors.dark,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          _label('Commentaire'),
          TextField(
            controller: _commentaire,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Précisions (optionnel)',
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                  : Text(
                      _isEdit ? 'Enregistrer' : 'Créer l\'immobilisation',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateModePill(String label, _DateMode mode) {
    final sel = _dateMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _dateMode = mode;
        if (mode == _DateMode.jour && _dateDebut != null) _dateFin = _dateDebut;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.headerButton,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? Colors.white : AppColors.dark,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.label)),
      );
}

class _SelectorField extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _SelectorField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? AppColors.fieldFill : AppColors.border,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.hint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasValue ? value! : hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: hasValue ? AppColors.dark : AppColors.hint,
                ),
              ),
            ),
            if (!enabled)
              const Icon(Icons.lock_outline_rounded,
                  size: 18, color: AppColors.hint)
            else
              const Icon(Icons.chevron_right, size: 20, color: AppColors.hint),
          ],
        ),
      ),
    );
  }
}
