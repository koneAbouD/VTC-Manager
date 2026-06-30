import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../chauffeur/domain/entities/chauffeur.dart';
import '../../../chauffeur/presentation/pages/chauffeur_detail_page.dart'
    show ChauffeurProgrammeCalculator;
import '../../../chauffeur/presentation/pages/chauffeur_selector_page.dart';
import '../../../chauffeur/presentation/providers/chauffeur_provider.dart';
import '../../../condition_travail/domain/entities/programme_chauffeur.dart';
import '../../domain/entities/indisponibilite.dart';
import '../providers/indisponibilite_provider.dart';

const _motifs = ['Congé', 'Maladie', 'Suspension', 'Formation', 'Personnel', 'Autre'];

/// Une indisponibilité porte soit sur un jour précis, soit sur une période.
enum _DateMode { jour, periode }

class IndisponibiliteFormPage extends ConsumerStatefulWidget {
  final Indisponibilite? initial;
  const IndisponibiliteFormPage({super.key, this.initial});

  @override
  ConsumerState<IndisponibiliteFormPage> createState() => _FormState();
}

class _FormState extends ConsumerState<IndisponibiliteFormPage> {
  int? _chauffeurId;
  String? _chauffeurNom;
  int? _remplacantId;
  String? _remplacantNom;
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
      _chauffeurId = i.chauffeurId;
      _chauffeurNom = i.chauffeurNom;
      _remplacantId = i.chauffeurRemplacantId;
      _remplacantNom = i.chauffeurRemplacantNom;
      _dateDebut = i.dateDebut;
      _dateFin = i.dateFin;
      _motif = i.motif;
      _commentaire.text = i.commentaire ?? '';
      // Un seul jour si fin absente ou égale au début.
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

  Future<Chauffeur?> _pickChauffeur() async {
    return Navigator.push<Chauffeur>(
      context,
      MaterialPageRoute(builder: (_) => const ChauffeurSelectorPage()),
    );
  }

  Future<void> _pickJour() async {
    final today = DateUtils.dateOnly(DateTime.now());
    // Jamais de jour passé (création comme modification) : on ne touche pas au
    // passé déjà écoulé d'une indisponibilité.
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
        _dateFin = picked; // un jour : début = fin
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
        // Jamais de jour passé (création comme modification).
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
    // Les erreurs alimentent aussi le bandeau persistant en haut du formulaire.
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
    if (_chauffeurId == null) {
      _toast('Veuillez sélectionner un chauffeur.', error: true);
      return;
    }
    if (_remplacantId == null) {
      _toast('Veuillez sélectionner un chauffeur remplaçant.', error: true);
      return;
    }
    if (_remplacantId == _chauffeurId) {
      _toast('Le remplaçant doit être différent du chauffeur.', error: true);
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
    // En mode « jour », la fin est calée sur le début.
    if (_dateMode == _DateMode.jour) _dateFin = _dateDebut;
    // Pas de définition dans le passé (uniquement à la création).
    if (!_isEdit) {
      final today = DateUtils.dateOnly(DateTime.now());
      if (DateUtils.dateOnly(_dateDebut!).isBefore(today)) {
        _toast(
            "L'indisponibilité ne peut pas être définie sur une date ou une période antérieure à aujourd'hui.",
            error: true);
        return;
      }
    }
    if (_dateFin != null && _dateFin!.isBefore(_dateDebut!)) {
      _toast('La date de fin doit être après la date de début.', error: true);
      return;
    }

    setState(() => _loading = true);

    // Contrôle client (même règle que le backend) : le chauffeur doit travailler
    // au moins un jour de l'intervalle. Couvre le cas « un seul jour » et la
    // période (refus si aucun jour travaillé).
    {
      final fin = _dateFin ?? _dateDebut!;
      final travaille =
          await _chauffeurTravailleAuMoinsUnJour(_chauffeurId!, _dateDebut!, fin);
      if (!mounted) return;
      if (!travaille) {
        setState(() => _loading = false);
        _toast(
            _dateMode == _DateMode.jour
                ? 'Le chauffeur ne travaille pas ce jour-là : aucune indisponibilité nécessaire.'
                : 'Le chauffeur ne travaille aucun jour de la période sélectionnée.',
            error: true);
        return;
      }
    }

    final entity = Indisponibilite(
      chauffeurId: _chauffeurId!,
      chauffeurRemplacantId: _remplacantId,
      dateDebut: _dateDebut!,
      dateFin: _dateFin,
      motif: _motif,
      commentaire:
          _commentaire.text.trim().isEmpty ? null : _commentaire.text.trim(),
    );

    final notifier = ref.read(indisponibiliteNotifierProvider.notifier);
    final err = _isEdit
        ? await notifier.update(widget.initial!.id!, entity)
        : await notifier.create(entity);

    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      _toast(err, error: true);
    } else {
      // Le statut des chauffeurs (titulaire → En congé, remplaçant → En service)
      // est recalculé côté backend : recharger la liste pour le refléter aussitôt.
      ref.read(chauffeurNotifierProvider.notifier).loadChauffeurs();
      _toast(_isEdit ? 'Indisponibilité modifiée.' : 'Indisponibilité créée.');
      Navigator.pop(context);
    }
  }

  /// Vrai si le chauffeur travaille (conduit) au moins un jour de l'intervalle
  /// [debut, fin], d'après son programme. Même logique que le calendrier.
  Future<bool> _chauffeurTravailleAuMoinsUnJour(
      int chauffeurId, DateTime debut, DateTime fin) async {
    try {
      final chauffeur =
          await ref.read(chauffeurByIdProvider(chauffeurId).future);
      final programme = chauffeur.programmeTravail;
      if (programme == null) return false;
      ProgrammeChauffeur? pc;
      for (final p in programme.chauffeurs) {
        if (p.chauffeurId == chauffeurId) {
          pc = p;
          break;
        }
      }
      if (pc == null) return false;

      var jour = DateUtils.dateOnly(debut);
      final dernier = DateUtils.dateOnly(fin);
      int garde = 0;
      while (!jour.isAfter(dernier) && garde++ < 1000) {
        if (ChauffeurProgrammeCalculator.travaille(programme, pc, jour)) {
          return true;
        }
        jour = jour.add(const Duration(days: 1));
      }
      return false;
    } catch (_) {
      // En cas d'échec de récupération, on laisse le backend trancher.
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy', 'fr_FR');
    return Scaffold(
      appBar: AppHeader(
          title: _isEdit ? 'Modifier l\'indisponibilité' : 'Nouvelle indisponibilité'),
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
              ? 'Chauffeur indisponible (non modifiable)'
              : 'Chauffeur indisponible *'),
          _SelectorField(
            value: _chauffeurNom,
            hint: 'Sélectionner un chauffeur',
            icon: Icons.person_outline_rounded,
            // Le chauffeur concerné ne peut pas être changé sur une
            // indisponibilité existante (ce serait une autre indisponibilité).
            enabled: !_isEdit,
            onTap: () async {
              final c = await _pickChauffeur();
              if (c != null) {
                setState(() {
                  _chauffeurId = c.id;
                  _chauffeurNom = c.displayName;
                });
              }
            },
          ),
          const SizedBox(height: 16),

          _label('Chauffeur remplaçant *'),
          _SelectorField(
            value: _remplacantNom,
            hint: 'Sélectionner un remplaçant',
            icon: Icons.switch_account_outlined,
            onClear: _remplacantId == null
                ? null
                : () => setState(() {
                      _remplacantId = null;
                      _remplacantNom = null;
                    }),
            onTap: () async {
              final c = await _pickChauffeur();
              if (c != null) {
                setState(() {
                  _remplacantId = c.id;
                  _remplacantNom = c.displayName;
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
                  : Text(_isEdit ? 'Enregistrer' : 'Créer l\'indisponibilité',
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
        // En repassant en « jour », on cale la fin sur le début.
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
  final VoidCallback? onClear;

  /// Quand false, le champ est verrouillé (non cliquable, grisé, icône cadenas).
  final bool enabled;

  const _SelectorField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.onClear,
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
            else if (hasValue && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 18, color: AppColors.hint),
              )
            else
              const Icon(Icons.chevron_right, size: 20, color: AppColors.hint),
          ],
        ),
      ),
    );
  }
}
