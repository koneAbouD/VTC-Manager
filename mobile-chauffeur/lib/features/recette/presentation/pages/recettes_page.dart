import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/ligne_card.dart';
import '../../../../core/widgets/liste_filtree.dart';
import '../../../../core/widgets/statut_style.dart';
import '../../domain/entities/ligne_recette.dart';
import '../providers/recette_providers.dart';

const _statutsRecette = [
  StatutOption(value: 'EN_ATTENTE', label: 'En attente', color: Colors.orange),
  StatutOption(
      value: 'PARTIELLEMENT_ENCAISSE', label: 'Partiel', color: Colors.blue),
  StatutOption(value: 'ENCAISSE', label: 'Encaissé', color: Colors.green),
  StatutOption(value: 'ANNULEE', label: 'Annulée', color: Colors.grey),
];

class RecettesPage extends ConsumerWidget {
  const RecettesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(titre: 'Recettes'),
            Expanded(
              child: ListeFiltree<LigneRecette>(
                valeur: ref.watch(recettesProvider),
                messageVide: 'Aucune recette pour le moment.',
                onRefresh: () async {
                  ref.invalidate(recettesProvider);
                  await ref.read(recettesProvider.future);
                },
                dateOf: (r) => DateTime.tryParse(r.date ?? ''),
                statutOf: (r) => r.statut,
                statuts: _statutsRecette,
                rechercheOf: (r) =>
                    '${Fmt.money(r.montantAttendu)} ${Fmt.date(r.date)} ${r.statut ?? ''}',
                itemBuilder: (r) => _card(r),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(LigneRecette r) {
    final (couleur, icone) = statutStyle(r.statut);
    final reste = r.montantRestant ?? 0;
    return LigneCard(
      icone: icone,
      couleur: couleur,
      titre: Fmt.money(r.montantAttendu),
      sousTitre: 'Le ${Fmt.date(r.date)}',
      trailing: reste > 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Reste',
                    style: TextStyle(fontSize: 10, color: Colors.black45)),
                Text(Fmt.money(reste),
                    style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            )
          : Text('+${Fmt.money(r.montantAttendu)}',
              style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
    );
  }
}
