import 'package:flutter/material.dart';

import '../../domain/entities/contravention.dart';

class ContraventionCard extends StatelessWidget {
  final Contravention contravention;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPay;

  const ContraventionCard({
    super.key,
    required this.contravention,
    this.onEdit,
    this.onDelete,
    this.onPay,
  });

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  String _formatMontant(double montant) =>
      '${montant.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.gavel,
                      color: theme.colorScheme.onErrorContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatMontant(contravention.montant),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _StatutBadge(statut: contravention.statut),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(contravention.dateInfraction),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
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
            if (contravention.typeInfraction != null) ...[
              const SizedBox(height: 6),
              Text(
                contravention.typeInfraction!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (contravention.vehiculeNom != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    contravention.vehiculeNom!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (!contravention.isPaid && onPay != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Payer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final String? statut;
  const _StatutBadge({this.statut});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (statut) {
      case 'PAYEE':
        color = Colors.green;
        break;
      case 'PARTIELLEMENT_PAYEE':
        color = Colors.orange;
        break;
      default:
        color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        statut ?? 'IMPAYEE',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
