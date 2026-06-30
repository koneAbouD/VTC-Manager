import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/operation_financiere.dart';
import '../../domain/enums/statut_operation.dart';
import '../../domain/enums/type_operation.dart';

class OperationFinanciereCard extends StatelessWidget {
  final OperationFinanciere operation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onAnnuler;

  const OperationFinanciereCard({
    super.key,
    required this.operation,
    required this.onEdit,
    required this.onDelete,
    this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    final isRevenu = operation.typeOperation == TypeOperation.REVENU;
    final accentColor = isRevenu ? Colors.green : Colors.red;
    final money = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icône type ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isRevenu ? Icons.arrow_downward : Icons.arrow_upward,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // ── Contenu ────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            money.format(operation.montant),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: accentColor,
                            ),
                          ),
                        ),
                        _StatutBadge(statut: operation.statut),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (operation.categorieLibelle != null)
                          operation.categorieLibelle!,
                        if (operation.sousCategorieLibelle != null)
                          operation.sousCategorieLibelle!,
                      ].join(' › '),
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          dateFmt.format(operation.dateOperation),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                        if (operation.chauffeurNom != null) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.person_outline,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              operation.chauffeurNom!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (operation.reference != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          operation.reference!,
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                              fontFamily: 'monospace'),
                        ),
                      ),
                  ],
                ),
              ),
              // ── Menu actions ───────────────────────────────────────────
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: Colors.grey.shade400, size: 20),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'annuler') onAnnuler?.call();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Modifier'),
                          contentPadding: EdgeInsets.zero,
                          dense: true)),
                  if (operation.statut.estTerminee &&
                      onAnnuler != null)
                    const PopupMenuItem(
                        value: 'annuler',
                        child: ListTile(
                            leading: Icon(Icons.cancel_outlined,
                                color: Colors.orange),
                            title: Text('Annuler'),
                            contentPadding: EdgeInsets.zero,
                            dense: true)),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                          leading:
                              Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Supprimer',
                              style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                          dense: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final StatutOperation statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (statut) {
      StatutOperation.ENCAISSE => (Colors.green, Icons.check_circle_outline),
      StatutOperation.PAYE => (Colors.green, Icons.check_circle_outline),
      StatutOperation.ANNULEE => (Colors.grey, Icons.cancel_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            statut.libelle,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
