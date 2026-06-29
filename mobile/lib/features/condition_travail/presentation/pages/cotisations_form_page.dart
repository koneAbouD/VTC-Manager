import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/configuration_recette.dart';
import '../../domain/entities/cotisation_recette.dart';
import '../../domain/enums/type_recette_configuration.dart';
import '../../../vehicule/domain/entities/vehicule.dart';
import '../providers/configuration_recette_provider.dart';
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

// ── Banner inline (bottom sheets) ─────────────────────────────────────────────
class _InlineToastBanner extends StatelessWidget {
  final String? message;
  final _ToastType type;
  const _InlineToastBanner({super.key, this.message, this.type = _ToastType.error});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final (Color bg, IconData icon) = switch (type) {
      _ToastType.success => (const Color(0xFF1B5E20), Icons.check_circle_outline_rounded),
      _ToastType.error   => (const Color(0xFFB71C1C), Icons.error_outline_rounded),
      _ToastType.warning => (const Color(0xFFE65100), Icons.warning_amber_rounded),
      _ToastType.info    => (const Color(0xFF1A237E), Icons.info_outline_rounded),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message!,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.white))),
      ]),
    );
  }
}

class CotisationsFormPage extends ConsumerStatefulWidget {
  final Vehicule vehicule;
  final ConfigurationRecette configuration;

  const CotisationsFormPage({
    super.key,
    required this.vehicule,
    required this.configuration,
  });

  @override
  ConsumerState<CotisationsFormPage> createState() =>
      _CotisationsFormPageState();
}

class _CotisationsFormPageState extends ConsumerState<CotisationsFormPage> {
  late List<CotisationRecette> _cotisations;
  bool _saving = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _cotisations = [...widget.configuration.cotisationsTriees];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: const AppHeader(title: 'Cotisations'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppErrorBanner(
                message: _submitError!,
                onClose: () => setState(() => _submitError = null),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'Cotisations',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                ),
                const SizedBox(width: 8),
                Text(
                  '(Optionnel)',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Si vous ajoutez des cotisations, elles seront prélevées\nsur la recette des chauffeurs',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(builder: (context) {
              final disabled = _saving ||
                  widget.configuration.typeRecette ==
                      TypeRecetteConfiguration.montantReel;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: disabled ? null : () => _showAddSheet(),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: disabled
                                ? Colors.grey.shade300
                                : const Color(0xFF43A047),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add,
                              color: disabled
                                  ? Colors.grey.shade500
                                  : Colors.white,
                              size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ajouter une cotisation',
                          style: TextStyle(
                            color: disabled
                                ? Colors.grey.shade400
                                : const Color(0xFF43A047),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.configuration.typeRecette ==
                      TypeRecetteConfiguration.montantReel) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Non disponible en mode Montant réel',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _cotisations.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _cotisations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _CotisationCard(
                      cotisation: _cotisations[index],
                      onEdit: () => _showAddSheet(index: index),
                      onDelete: () => _deleteCotisation(index),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                padding: const EdgeInsets.symmetric(vertical: 18),
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
                  : const Text('Mettre à jour', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSheet({int? index}) async {
    final existing = index != null ? _cotisations[index] : null;
    final result = await showModalBottomSheet<CotisationRecette>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddCotisationSheet(initial: existing),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _cotisations[index] = result.copyWith(ordre: index + 1);
      } else {
        _cotisations.add(result.copyWith(ordre: _cotisations.length + 1));
      }
    });
  }

  void _deleteCotisation(int index) {
    setState(() {
      _cotisations.removeAt(index);
      for (int i = 0; i < _cotisations.length; i++) {
        _cotisations[i] = _cotisations[i].copyWith(ordre: i + 1);
      }
    });
  }

  Future<void> _save() async {
    if (widget.vehicule.id == null) return;

    setState(() {
      _saving = true;
      _submitError = null;
    });

    final updated = widget.configuration.copyWith(
      cotisations: _cotisations,
    );

    final error = await ref
        .read(configurationRecetteControllerProvider)
        .saveConfiguration(widget.vehicule.id!, updated);

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      setState(() => _submitError = error);
      _appToast(context, error, type: _ToastType.error);
      return;
    }

    _appToast(context, 'Cotisations mises à jour.');
    Navigator.pop(context);
  }
}

// ── Cotisation card ────────────────────────────────────────────────────────

class _CotisationCard extends StatelessWidget {
  final CotisationRecette cotisation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CotisationCard({
    required this.cotisation,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cotisation.nom,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${fmt.format(cotisation.montant.toInt())} XOF',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined,
                color: Color(0xFF43A047), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFD32F2F), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Add/Edit bottom sheet ──────────────────────────────────────────────────

class _AddCotisationSheet extends StatefulWidget {
  final CotisationRecette? initial;
  const _AddCotisationSheet({this.initial});

  @override
  State<_AddCotisationSheet> createState() => _AddCotisationSheetState();
}

class _AddCotisationSheetState extends State<_AddCotisationSheet> {
  late TextEditingController _nomController;
  late TextEditingController _montantController;

  // ── Inline toast ──
  String? _inlineMsg;
  _ToastType _inlineType = _ToastType.error;
  Timer? _inlineTimer;

  void _showInline(String msg, {_ToastType type = _ToastType.error}) {
    _inlineTimer?.cancel();
    setState(() { _inlineMsg = msg; _inlineType = type; });
    _inlineTimer = Timer(
      Duration(seconds: type == _ToastType.error || type == _ToastType.warning ? 4 : 2),
      () { if (mounted) setState(() => _inlineMsg = null); },
    );
  }

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.initial?.nom ?? '');
    _montantController = TextEditingController(
      text: widget.initial?.montant != null
          ? widget.initial!.montant.toInt().toString()
          : '',
    );
  }

  @override
  void dispose() {
    _inlineTimer?.cancel();
    _nomController.dispose();
    _montantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // ── Banner inline ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _InlineToastBanner(
                  key: ValueKey(_inlineMsg), message: _inlineMsg, type: _inlineType),
            ),
            const Text(
              'Ajouter une cotisation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 20),
            Text(
              'Nom de la cotisation',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nomController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Montant à cotiser (XOF)',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _montantController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFFF9A825), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cet montant sera déduit de la recette',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF43A047),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Ajouter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final nom = _nomController.text.trim();
    if (nom.isEmpty) {
      _showInline('Le nom de la cotisation est obligatoire.');
      return;
    }
    final montant = double.tryParse(_montantController.text.trim());
    if (montant == null || montant <= 0) {
      _showInline('Le montant doit être strictement positif.');
      return;
    }
    Navigator.pop(
      context,
      CotisationRecette(
        id: widget.initial?.id,
        nom: nom,
        montant: montant,
        ordre: widget.initial?.ordre ?? 0,
      ),
    );
  }
}
