import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/operation_financiere.dart';

/// Tuile d'opération (revenu vert / dépense rouge), réutilisée sur l'accueil et
/// la page « Mes opérations ».
class OperationTile extends StatelessWidget {
  final OperationFinanciere op;
  const OperationTile({super.key, required this.op});

  @override
  Widget build(BuildContext context) {
    final color = op.isRevenu ? AppColors.success : AppColors.error;
    final sign = op.isRevenu ? '+' : '-';
    final annulee = op.estAnnulee;
    final sousTitre = [
      if (op.vehicule != null) op.vehicule!,
      if (op.chauffeur != null) op.chauffeur!,
    ].join(' - ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              op.isRevenu
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        op.libelle ?? 'Opération',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: annulee ? AppColors.error : null,
                            decoration:
                                annulee ? TextDecoration.lineThrough : null),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$sign${Fmt.money(op.montant)}',
                      style: TextStyle(
                          color: annulee ? AppColors.error : color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration:
                              annulee ? TextDecoration.lineThrough : null),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sousTitre,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Fmt.date(op.date),
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
