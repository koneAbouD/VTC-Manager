import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/liste_filtree.dart';
import '../../domain/entities/operation_financiere.dart';
import '../providers/operation_providers.dart';
import '../widgets/operation_tile.dart';

const _statutsOperation = [
  StatutOption(value: 'REVENU', label: 'Revenus', color: Colors.green),
  StatutOption(value: 'DEPENSE', label: 'Dépenses', color: Colors.red),
];

/// Liste complète des opérations liées au chauffeur ou à son véhicule.
class OperationsPage extends ConsumerWidget {
  const OperationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(titre: 'Mes opérations'),
            Expanded(
              child: ListeFiltree<OperationFinanciere>(
                valeur: ref.watch(operationsProvider),
                messageVide: 'Aucune opération pour le moment.',
                onRefresh: () async {
                  ref.invalidate(operationsProvider);
                  await ref.read(operationsProvider.future);
                },
                dateOf: (op) => DateTime.tryParse(op.date ?? ''),
                statutOf: (op) => op.isRevenu ? 'REVENU' : 'DEPENSE',
                statuts: _statutsOperation,
                rechercheOf: (op) =>
                    '${op.libelle ?? ''} ${op.vehicule ?? ''} ${op.chauffeur ?? ''} ${Fmt.money(op.montant)}',
                hintRecherche: 'Rechercher une opération...',
                itemBuilder: (op) => OperationTile(op: op),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
