import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ligne_card.dart';
import '../../../../core/widgets/liste_filtree.dart';
import '../../../../core/widgets/statut_style.dart';
import '../../domain/entities/contravention.dart';
import '../providers/contravention_providers.dart';

/// Contenu body-only (embarqué dans l'onglet Contraventions & Amendes).
class ContraventionsPage extends ConsumerWidget {
  const ContraventionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListeFiltree<Contravention>(
      valeur: ref.watch(contraventionsProvider),
      messageVide: 'Aucune contravention. Bonne route !',
      onRefresh: () async {
        ref.invalidate(contraventionsProvider);
        await ref.read(contraventionsProvider.future);
      },
      dateOf: (c) => DateTime.tryParse(c.date ?? ''),
      rechercheOf: (c) =>
          '${c.type ?? ''} ${c.lieu ?? ''} ${Fmt.money(c.montant)}',
      hintRecherche: 'Rechercher une infraction...',
      itemBuilder: (c) {
        final (couleur, icone) = statutStyle(c.statut);
        return LigneCard(
          icone: icone,
          couleur: couleur,
          titre: c.type ?? 'Infraction',
          sousTitre: 'Le ${Fmt.date(c.date)}'
              '${c.lieu != null ? ' • ${c.lieu}' : ''}',
          trailing: Text(
            Fmt.money(c.montant),
            style: TextStyle(
                color: couleur, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        );
      },
    );
  }
}
