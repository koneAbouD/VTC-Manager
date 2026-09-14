import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cotisation/domain/entities/ligne_cotisation.dart';
import '../../features/cotisation/domain/entities/ligne_cotisation_filtres.dart';
import '../../features/cotisation/presentation/providers/ligne_cotisation_provider.dart';
import '../../features/recette/domain/entities/ligne_recette.dart';

/// Pendant de `ligne_jumelle_encaissement.dart` du côté de l'annulation : une
/// journée qui n'a pas eu lieu ne doit rien laisser derrière elle, ni recette
/// ni cotisation.
///
/// La liste sert **à proposer** la case à cocher, pas à décider : c'est le
/// serveur qui écarte, à la validation, ce qui ne peut plus être annulé.
/// Un appel qui échoue rend une liste vide — la commodité ne doit jamais
/// empêcher d'annuler la recette que l'utilisateur a ouverte.
Future<List<LigneCotisation>> chercherCotisationsAnnulablesDuMemeJour(
  WidgetRef ref,
  LigneRecette ligne,
) async {
  final jour = DateUtils.dateOnly(ligne.dateRecette);

  final resultat =
      await ref.read(ligneCotisationRepositoryProvider).getLignes(
            LigneCotisationFiltres(
              vehiculeId:  ligne.vehiculeId,
              chauffeurId: ligne.chauffeurId,
              dateDebut:   jour,
              dateFin:     jour,
            ),
          );

  return resultat.fold((_) => const <LigneCotisation>[], (lignes) {
    return lignes.where((c) {
      if (c.id == null || !c.estActive) return false;
      if (DateUtils.dateOnly(c.dateCotisation) != jour) return false;
      // Une cotisation déjà servie touche la trésorerie : elle exige d'abord la
      // contre-passation de ses versements, et le serveur la refuserait.
      return c.montantEncaisse <= 0;
    }).toList();
  });
}
