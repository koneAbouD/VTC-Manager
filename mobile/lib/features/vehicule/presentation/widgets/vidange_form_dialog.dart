import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../providers/vidanges_provider.dart';

// ── Palette (cohérente avec EncaissementLigneDialog / MaintenanceFormPage) ────

const _kPrimary   = Color(0xFF3B5BDB);
const _kGreen     = Color(0xFF2E7D32);
const _kFieldFill = Color(0xFFF2F3F5);
const _kHint      = Color(0xFF9AA0AE);
const _kLabel     = Color(0xFF6B7280);
const _kBorder    = Color(0xFFE3E6EE);
const _kDark      = Color(0xFF1A1A2E);
const _kError     = Color(0xFFE03131);

String _grouped(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');

// ── Toast ─────────────────────────────────────────────────────────────────────

void _showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          error
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
        ),
      ]),
      backgroundColor:
          error ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration:
          error ? const Duration(seconds: 4) : const Duration(seconds: 2),
    ));
}

// ── Entrée ────────────────────────────────────────────────────────────────────

/// Ouvre le bottom sheet d'enregistrement d'une vidange (même style que la
/// popup d'encaissement). Retourne `true` si une vidange a été créée.
Future<bool?> showVidangeFormDialog(
  BuildContext context, {
  required int vehiculeId,
  int? kilometrageActuel,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFF8F9FB),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _VidangeFormSheet(
      vehiculeId: vehiculeId,
      kilometrageActuel: kilometrageActuel,
    ),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _VidangeFormSheet extends ConsumerStatefulWidget {
  final int vehiculeId;
  final int? kilometrageActuel;

  const _VidangeFormSheet({
    required this.vehiculeId,
    this.kilometrageActuel,
  });

  @override
  ConsumerState<_VidangeFormSheet> createState() => _VidangeFormSheetState();
}

class _VidangeFormSheetState extends ConsumerState<_VidangeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _kmVidangeCtrl;
  final _kmProchaineCtrl = TextEditingController();

  DateTime _dateVidange = DateTime.now();
  DateTime? _dateProchaine;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _kmVidangeCtrl = TextEditingController(
      text: widget.kilometrageActuel != null ? '${widget.kilometrageActuel}' : '',
    );
  }

  @override
  void dispose() {
    _kmVidangeCtrl.dispose();
    _kmProchaineCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool prochaine}) async {
    final initial = prochaine
        ? (_dateProchaine ?? _dateVidange.add(const Duration(days: 30)))
        : _dateVidange;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: initial,
        firstDate: prochaine ? _dateVidange : DateTime(2015),
        lastDate: DateTime(2100),
      ),
    );
    if (picked != null) {
      setState(() {
        if (prochaine) {
          _dateProchaine = picked;
        } else {
          _dateVidange = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final vidange = Vidange(
      dateVidange: _dateVidange,
      kilometrageVidange: int.parse(_kmVidangeCtrl.text.trim()),
      dateProchaineVidange: _dateProchaine,
      kilometrageProchaineVidange: _kmProchaineCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_kmProchaineCtrl.text.trim()),
    );

    String? error;
    try {
      await creerVidange(ref, vehiculeId: widget.vehiculeId, vidange: vidange);
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Enregistrement impossible : $e';
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitError = error;
    });

    if (error == null) {
      Navigator.pop(context, true);
      _showToast(context, 'Vidange enregistrée avec succès');
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + keyboardHeight + bottomSafe),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Indicateur ────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Titre ─────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'Enregistrer une vidange',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _kDark,
                    letterSpacing: -0.4),
              ),
            ),

            // ── Info kilométrage actuel ───────────────────────────────
            if (widget.kilometrageActuel != null) ...[
              _InfoCard(
                titre: 'Kilométrage actuel',
                sousTitre: 'Relevé enregistré du véhicule',
                badge: '${_grouped(widget.kilometrageActuel!)} km',
                couleur: _kPrimary,
                icone: Icons.speed_outlined,
              ),
              const SizedBox(height: 12),
            ],

            // ── Vidange effectuée ─────────────────────────────────────
            _FormCard(
              icon: Icons.oil_barrel_outlined,
              accent: _kGreen,
              title: 'Vidange effectuée',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LabeledField(
                    label: 'Date de la vidange',
                    isRequired: true,
                    child: _DateBox(
                      value: _dateVidange,
                      onTap: () => _pickDate(prochaine: false),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Kilométrage à la vidange',
                    isRequired: true,
                    child: TextFormField(
                      controller: _kmVidangeCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(fontSize: 15, color: _kDark),
                      decoration: _fieldDeco('0').copyWith(
                        suffixText: 'km',
                        suffixStyle: const TextStyle(
                            color: _kLabel,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Kilométrage requis';
                        }
                        if (int.tryParse(v.trim()) == null) {
                          return 'Nombre invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Prochaine vidange ─────────────────────────────────────
            _FormCard(
              icon: Icons.event_repeat_outlined,
              accent: _kPrimary,
              title: 'Prochaine vidange (optionnel)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LabeledField(
                    label: 'Date prévue',
                    child: _DateBox(
                      value: _dateProchaine,
                      placeholder: 'Non définie',
                      onTap: () => _pickDate(prochaine: true),
                      onClear: _dateProchaine != null
                          ? () => setState(() => _dateProchaine = null)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Kilométrage prévu',
                    child: TextFormField(
                      controller: _kmProchaineCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(fontSize: 15, color: _kDark),
                      decoration: _fieldDeco('Ex. 150 000').copyWith(
                        suffixText: 'km',
                        suffixStyle: const TextStyle(
                            color: _kLabel,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v.trim());
                        if (n == null) return 'Nombre invalide';
                        final km = int.tryParse(_kmVidangeCtrl.text.trim());
                        if (km != null && n < km) {
                          return 'Doit être ≥ au km de la vidange';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Erreur de soumission ──────────────────────────────────
            if (_submitError != null) ...[
              AppErrorBanner(
                message: _submitError!,
                onClose: () => setState(() => _submitError = null),
              ),
              const SizedBox(height: 10),
            ],

            // ── Bouton ────────────────────────────────────────────────
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _submitting ? 'Enregistrement…' : 'Enregistrer',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── Champ date (aspect identique à _fieldDeco, mais tappable) ─────────────────

class _DateBox extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  final String placeholder;
  final VoidCallback? onClear;

  const _DateBox({
    required this.value,
    required this.onTap,
    this.placeholder = '',
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 17, color: _kHint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasValue
                  ? DateFormat('dd MMM yyyy', 'fr_FR').format(value!)
                  : placeholder,
              style: TextStyle(
                  fontSize: 15,
                  color: hasValue ? _kDark : _kHint,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400),
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded, size: 17, color: _kHint),
            )
          else
            const Icon(Icons.expand_more_rounded, size: 20, color: _kHint),
        ]),
      ),
    );
  }
}

// ── Carte info (réplique EncaissementLigneDialog) ─────────────────────────────

class _InfoCard extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final String? badge;
  final Color couleur;
  final IconData icone;

  const _InfoCard({
    required this.titre,
    this.sousTitre,
    this.badge,
    required this.couleur,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, size: 18, color: couleur),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kDark)),
              if (sousTitre != null)
                Text(sousTitre!,
                    style: const TextStyle(fontSize: 11, color: _kHint)),
            ],
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: couleur),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Widgets locaux (réplique EncaissementLigneDialog) ─────────────────────────

class _FormCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final Widget child;

  const _FormCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kDark,
                      letterSpacing: -0.2)),
            ),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final Widget child;

  const _LabeledField({
    required this.label,
    this.isRequired = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kLabel)),
          if (isRequired) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(
                    color: _kError,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ]),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

InputDecoration _fieldDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kHint, fontSize: 15),
      filled: true,
      fillColor: _kFieldFill,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kError, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kError, width: 1.5),
      ),
    );
