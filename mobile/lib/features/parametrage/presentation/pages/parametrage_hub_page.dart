import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
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
        data: (referentiels) => ListView.separated(
          // Padding bas incluant l'inset de la barre de navigation Android pour
          // que la dernière carte ne passe pas sous la barre système.
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
          // Référentiels dynamiques du méta-catalogue. Les réglages globaux
          // (« Paramétrage généraux ») ont leur propre entrée dans les
          // paramètres de l'application.
          itemCount: referentiels.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final descriptor = referentiels[i];
            return _HubTile(
              icon: Icons.tune_rounded,
              libelle: descriptor.libelle,
              description: descriptor.description,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReferentielListePage(descriptor: descriptor),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String libelle;
  final String description;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.libelle,
    required this.description,
    required this.onTap,
  });

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
              // Icône nue, sans pastille. La boîte garde ses 44 px : c'est elle
              // qui aligne les libellés d'une carte à l'autre.
              SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(libelle,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark)),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: AppColors.label)),
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
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.hint),
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
