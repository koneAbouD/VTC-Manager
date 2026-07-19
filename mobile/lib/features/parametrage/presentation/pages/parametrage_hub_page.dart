import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../data/parametrage_api.dart';
import '../providers/parametrage_providers.dart';
import 'referentiel_liste_page.dart';

/// Écran d'accueil du paramétrage des données de référence.
///
/// Liste les référentiels paramétrables à partir du meta-catalogue backend :
/// aucun écran n'est codé en dur, tout est piloté par le schéma renvoyé.
class ParametrageHubPage extends ConsumerWidget {
  const ParametrageHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Données de référence'),
      body: catalogue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Erreur(
          message: 'Impossible de charger les référentiels.',
          onRetry: () => ref.invalidate(catalogueProvider),
        ),
        data: (referentiels) => referentiels.isEmpty
            ? const Center(
                child: Text('Aucun référentiel disponible.',
                    style: TextStyle(color: AppColors.label)))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: referentiels.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ReferentielTile(
                  descriptor: referentiels[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReferentielListePage(descriptor: referentiels[i]),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ReferentielTile extends StatelessWidget {
  final ReferentielDescriptor descriptor;
  final VoidCallback onTap;

  const _ReferentielTile({required this.descriptor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(descriptor.libelle,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark)),
                    if (descriptor.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(descriptor.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, height: 1.3, color: AppColors.label)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Erreur extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Erreur({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.hint),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.label)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
