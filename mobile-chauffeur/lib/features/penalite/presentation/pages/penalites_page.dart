import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ligne_card.dart';
import '../../../../core/widgets/liste_filtree.dart';
import '../../../../core/widgets/statut_style.dart';
import '../../domain/entities/ligne_penalite.dart';
import '../providers/penalite_providers.dart';

/// Contenu body-only (embarqué dans l'onglet Contraventions & Amendes).
class PenalitesPage extends ConsumerWidget {
  const PenalitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListeFiltree<LignePenalite>(
      valeur: ref.watch(penalitesProvider),
      messageVide: 'Aucune amende. Continuez ainsi !',
      onRefresh: () async {
        ref.invalidate(penalitesProvider);
        await ref.read(penalitesProvider.future);
      },
      dateOf: (p) => DateTime.tryParse(p.date ?? ''),
      rechercheOf: (p) => '${p.type ?? ''} ${Fmt.money(p.montant)}',
      hintRecherche: 'Rechercher une amende...',
      itemBuilder: (p) {
        final (couleur, icone) = statutStyle(p.statut);
        final reste = p.montantRestant ?? 0;
        return LigneCard(
          icone: icone,
          couleur: couleur,
          titre: p.type ?? 'Amende',
          sousTitre: 'Le ${Fmt.date(p.date)}',
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(p.montant),
                  style: TextStyle(
                      color: couleur,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              if (reste > 0)
                Text('Reste ${Fmt.money(reste)}',
                    style:
                        const TextStyle(fontSize: 10, color: Colors.black45)),
            ],
          ),
        );
      },
    );
  }
}
