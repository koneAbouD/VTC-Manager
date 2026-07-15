import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/remplacant.dart';
import '../providers/indisponibilite_providers.dart';

const _motifs = ['Congé', 'Maladie', 'Suspension', 'Formation', 'Personnel', 'Autre'];

/// Une indisponibilité porte soit sur un jour précis, soit sur une période.
enum _DateMode { jour, periode }

/// Déclaration d'une indisponibilité par le chauffeur connecté.
class IndisponibiliteFormPage extends ConsumerStatefulWidget {
  const IndisponibiliteFormPage({super.key});

  @override
  ConsumerState<IndisponibiliteFormPage> createState() => _FormState();
}

class _FormState extends ConsumerState<IndisponibiliteFormPage> {
  int? _remplacantId;
  String? _remplacantNom;
  _DateMode _dateMode = _DateMode.jour;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  String? _motif;
  final _commentaire = TextEditingController();
  bool _loading = false;
  String? _submitError;

  final _fmt = DateFormat('dd MMM yyyy', 'fr_FR');

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  // ── Sélecteur de remplaçant (bottom sheet) ──────────────────────────────
  Future<void> _pickRemplacant() async {
    final r = await showModalBottomSheet<Remplacant>(
      context: context,
      showDragHandle: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final async = ref.watch(remplacantsProvider);
          return async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(messageFromError(e),
                  style: const TextStyle(color: AppColors.error)),
            ),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aucun remplaçant disponible.'),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Text('Choisir un remplaçant',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      ...list.map((rr) => ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primaryTint,
                              child: Icon(Icons.person_rounded,
                                  color: AppColors.primaryDark),
                            ),
                            title: Text(rr.nomComplet),
                            subtitle:
                                rr.telephone != null ? Text(rr.telephone!) : null,
                            onTap: () => Navigator.pop(context, rr),
                          )),
                    ],
                  ),
          );
        },
      ),
    );
    if (r != null) {
      setState(() {
        _remplacantId = r.id;
        _remplacantNom = r.nomComplet;
      });
    }
  }

  Future<void> _pickJour() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: (_dateDebut != null && !_dateDebut!.isBefore(today))
          ? _dateDebut!
          : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
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
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: (_dateDebut != null && _dateFin != null)
          ? DateTimeRange(start: _dateDebut!, end: _dateFin!)
          : null,
    );
    if (range != null) {
      setState(() {
        _dateDebut = range.start;
        _dateFin = range.end;
      });
    }
  }

  void _erreur(String msg) {
    setState(() => _submitError = msg);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);
    if (_remplacantId == null) {
      _erreur('Choisissez un chauffeur remplaçant.');
      return;
    }
    if (_dateDebut == null) {
      _erreur(_dateMode == _DateMode.jour
          ? 'Choisissez le jour.'
          : 'Choisissez la période.');
      return;
    }
    if (_dateMode == _DateMode.jour) _dateFin = _dateDebut;

    setState(() => _loading = true);
    final result = await ref.read(declarerIndisponibiliteUseCaseProvider).call(
          chauffeurRemplacantId: _remplacantId!,
          dateDebut: _iso(_dateDebut!),
          dateFin: _iso(_dateFin ?? _dateDebut!),
          motif: _motif,
          commentaire: _commentaire.text.trim().isEmpty
              ? null
              : _commentaire.text.trim(),
        );
    if (!mounted) return;
    result.fold(
      (f) {
        setState(() => _loading = false);
        _erreur(f.message);
      },
      (_) => Navigator.of(context).pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(titre: 'Nouvelle indisponibilité'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (_submitError != null) ...[
                    _ErrorBanner(
                      message: _submitError!,
                      onClose: () => setState(() => _submitError = null),
                    ),
                    const SizedBox(height: 16),
                  ],

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
                    onTap: _loading ? null : _pickRemplacant,
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
                        ? (_dateDebut == null ? null : _fmt.format(_dateDebut!))
                        : (_dateDebut == null || _dateFin == null
                            ? null
                            : '${_fmt.format(_dateDebut!)} → ${_fmt.format(_dateFin!)}'),
                    hint: _dateMode == _DateMode.jour
                        ? 'Choisir le jour'
                        : 'Choisir la période',
                    icon: _dateMode == _DateMode.jour
                        ? Icons.event_outlined
                        : Icons.date_range_outlined,
                    onTap: _loading
                        ? null
                        : (_dateMode == _DateMode.jour ? _pickJour : _pickPeriode),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                sel ? AppColors.primary : AppColors.headerButton,
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
                          : const Text("Déclarer l'indisponibilité",
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

/// Champ tappable (style formulaire de l'app gestionnaire).
class _SelectorField extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _SelectorField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
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
            if (hasValue && onClear != null)
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

/// Bandeau d'erreur en tête de formulaire.
class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _ErrorBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppColors.error, fontSize: 13))),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, size: 18, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
