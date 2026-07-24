import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../data/parametrage_api.dart';
import '../providers/parametrage_providers.dart';

/// Réglages globaux de l'application (paramètres clé-valeur). Chaque paramètre
/// est éditable individuellement ; la durée d'amortissement affiche en plus sa
/// conversion en années.
class ParametresGenerauxPage extends ConsumerStatefulWidget {
  const ParametresGenerauxPage({super.key});

  @override
  ConsumerState<ParametresGenerauxPage> createState() =>
      _ParametresGenerauxPageState();
}

class _ParametresGenerauxPageState
    extends ConsumerState<ParametresGenerauxPage> {
  final Map<String, TextEditingController> _ctrls = {};
  String? _savingCle;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(ParametreGeneral p) =>
      _ctrls.putIfAbsent(p.cle, () => TextEditingController(text: p.valeur));

  Future<void> _enregistrer(ParametreGeneral p) async {
    final valeur = _ctrlFor(p).text.trim();
    setState(() => _savingCle = p.cle);
    try {
      await ref
          .read(parametrageApiProvider)
          .mettreAJourParametre(p.cle, valeur);
      ref.invalidate(parametresProvider);
      if (!mounted) return;
      _toast('Paramètre enregistré.');
    } catch (e) {
      if (!mounted) return;
      _toast(messageFromError(e, fallback: "Échec de l'enregistrement."),
          erreur: true);
    } finally {
      if (mounted) setState(() => _savingCle = null);
    }
  }

  void _toast(String message, {bool erreur = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: erreur ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(parametresProvider);
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Paramètres généraux'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 48, color: AppColors.hint),
                const SizedBox(height: 12),
                const Text('Impossible de charger les paramètres.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.label)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(parametresProvider),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (params) => params.isEmpty
            ? const Center(
                child: Text('Aucun paramètre disponible.',
                    style: TextStyle(color: AppColors.label)))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: params.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _ParametreCard(
                  parametre: params[i],
                  controller: _ctrlFor(params[i]),
                  saving: _savingCle == params[i].cle,
                  onSave: () => _enregistrer(params[i]),
                  onChanged: () => setState(() {}),
                ),
              ),
      ),
    );
  }
}

class _ParametreCard extends StatelessWidget {
  final ParametreGeneral parametre;
  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onChanged;

  const _ParametreCard({
    required this.parametre,
    required this.controller,
    required this.saving,
    required this.onSave,
    required this.onChanged,
  });

  bool get _estDuree => parametre.cle == kCleDureeAmortissement;

  String? get _sousTexteAnnees {
    if (!_estDuree) return null;
    final mois = int.tryParse(controller.text.trim());
    if (mois == null || mois <= 0) return null;
    final annees = mois / 12;
    final str = annees == annees.roundToDouble()
        ? annees.toInt().toString()
        : annees.toStringAsFixed(1);
    return '≈ $str an${annees >= 2 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parametre.libelle,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark)),
          if (parametre.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(parametre.description,
                style: const TextStyle(
                    fontSize: 12, height: 1.35, color: AppColors.label)),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      keyboardType:
                          _estDuree ? TextInputType.number : TextInputType.text,
                      inputFormatters: _estDuree
                          ? [FilteringTextInputFormatter.digitsOnly]
                          : null,
                      onChanged: (_) => onChanged(),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.fieldFill,
                        suffixText: _estDuree ? 'mois' : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    if (_sousTexteAnnees != null) ...[
                      const SizedBox(height: 6),
                      Text(_sousTexteAnnees!,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: saving ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
