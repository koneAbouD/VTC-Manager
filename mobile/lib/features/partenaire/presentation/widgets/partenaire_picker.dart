import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/partenaire.dart';
import '../providers/partenaire_providers.dart';

/// Résultat d'un choix de partenaire : `null` en cas d'abandon, un [Partenaire]
/// sinon, ou [PartenaireChoix.parDefaut] pour revenir au partenaire de
/// l'intervention.
class PartenaireChoix {
  final Partenaire? partenaire;
  const PartenaireChoix(this.partenaire);

  static const PartenaireChoix parDefaut = PartenaireChoix(null);
}

/// Feuille de choix d'un partenaire, pensée pour être ouverte depuis une ligne
/// de liste — là où un champ complet prendrait trop de place.
///
/// Renvoie `null` si l'utilisateur ferme sans choisir.
Future<PartenaireChoix?> choisirPartenaire(
  BuildContext context,
  WidgetRef ref, {
  int? selectionId,
  String? libelleParDefaut,
}) {
  return showModalBottomSheet<PartenaireChoix>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PartenaireSheet(
      selectionId: selectionId,
      libelleParDefaut: libelleParDefaut,
    ),
  );
}

class _PartenaireSheet extends ConsumerWidget {
  final int? selectionId;
  final String? libelleParDefaut;

  const _PartenaireSheet({this.selectionId, this.libelleParDefaut});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partenaires = ref.watch(partenairesProvider(true));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Prestataire de la ligne',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark)),
            ),
          ),
          Flexible(
            child: partenaires.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Text('Partenaires indisponibles : $e',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.error)),
              ),
              data: (liste) => ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // Revenir au partenaire de l'intervention : la sortie la plus
                  // fréquente une fois qu'on a corrigé une ligne par erreur.
                  ListTile(
                    leading: const Icon(Icons.undo_rounded,
                        size: 20, color: AppColors.hint),
                    title: Text(
                        libelleParDefaut == null
                            ? 'Partenaire de l\'intervention'
                            : 'Partenaire de l\'intervention ($libelleParDefaut)',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.dark)),
                    trailing: selectionId == null
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: AppColors.primary)
                        : null,
                    onTap: () =>
                        Navigator.pop(context, PartenaireChoix.parDefaut),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  for (final p in liste.where((p) => p.id != null))
                    ListTile(
                      title: Text(p.nom,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.dark)),
                      subtitle: p.typeNom.isEmpty
                          ? null
                          : Text(p.typeNom,
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.hint)),
                      trailing: selectionId == p.id
                          ? const Icon(Icons.check_rounded,
                              size: 18, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, PartenaireChoix(p)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
