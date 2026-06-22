import 'package:flutter/material.dart';

import '../../domain/entities/chauffeur.dart';
import '../../domain/enums/chauffeur_status.dart';
import '../pages/chauffeur_detail_page.dart';

class ChauffeurCard extends StatelessWidget {
  final Chauffeur chauffeur;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ChauffeurCard({
    super.key,
    required this.chauffeur,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = '${chauffeur.prenom.isNotEmpty ? chauffeur.prenom[0] : ''}'
            '${chauffeur.nom.isNotEmpty ? chauffeur.nom[0] : ''}'
        .toUpperCase();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            ChauffeurAvatar(
              chauffeurId: chauffeur.id,
              initials: initials,
              hasPhoto: chauffeur.photoUrl != null &&
                  chauffeur.photoUrl!.isNotEmpty,
              size: 48,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chauffeur.displayName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  _StatutBadge(statut: chauffeur.statut),
                  if (chauffeur.vehiculeNom != null &&
                      chauffeur.vehiculeNom!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          chauffeur.vehiculeNom!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final ChauffeurStatus? statut;
  const _StatutBadge({this.statut});

  @override
  Widget build(BuildContext context) {
    final isActif = statut == ChauffeurStatus.actif;
    final color = isActif ? Colors.green : Colors.grey;
    final label = statut?.label ?? 'Inconnu';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
