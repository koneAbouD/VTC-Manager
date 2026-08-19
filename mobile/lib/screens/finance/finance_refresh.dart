import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cotisation/presentation/providers/ligne_cotisation_provider.dart';
import '../../features/penalite/presentation/providers/penalite_provider.dart';
import '../../features/recette/presentation/providers/ligne_recette_provider.dart';
import '../../features/tresorerie/presentation/providers/tresorerie_providers.dart';
import 'rapport_financier_page.dart';
import '../../features/partenaire/presentation/providers/partenaire_providers.dart';

/// Signal de rafraîchissement du module Finances : incrémenté par
/// [refreshFinances]. Les pages qui ne s'appuient pas sur un FutureProvider
/// invalidable (ex. la liste paginée des Opérations) l'écoutent pour se
/// recharger en conservant leurs filtres.
final financeRefreshTickProvider = StateProvider<int>((ref) => 0);

/// Rafraîchit **immédiatement toutes les pages du module Finances** après une
/// opération (encaissement, annulation de ligne, création/annulation
/// d'opération, transfert, clôture de caisse…).
///
/// - invalide les FutureProviders « photo » (Trésorerie, Créances, Compte de
///   résultat, Marges, Bilan, Clôtures, Rapport financier) → refetch au
///   prochain `watch` (l'onglet visible se rafraîchit tout de suite, les autres
///   à leur réaffichage) ;
/// - invalide les fiches détail recette/cotisation/pénalité, dont le drapeau
///   « restaurable » dépend des arrêtés que la clôture vient de déplacer ;
/// - incrémente le tick pour l'onglet Opérations (liste paginée).
void refreshFinances(WidgetRef ref) {
  ref.invalidate(tresorerieSummaryProvider);
  ref.invalidate(balanceAgeeProvider);
  ref.invalidate(balanceAgeeVehiculeProvider);
  ref.invalidate(creancesChauffeurProvider);
  ref.invalidate(creancesVehiculeProvider);
  ref.invalidate(compteResultatProvider);
  ref.invalidate(margesVehiculesProvider);
  ref.invalidate(bilanProvider);
  ref.invalidate(cloturesPeriodeProvider);
  // Un comptage crée un écart à trancher, son retrait le fait disparaître, et
  // une imputation le sort de la liste : les trois passent par ici.
  ref.invalidate(ecartsEnAttenteProvider);
  ref.invalidate(rapportFinancierProvider);
  // Une facture reçue change la dette au bilan ; un règlement change la caisse.
  ref.invalidate(echeancierProvider);
  ref.invalidate(facturesDuMoisProvider);
  // Une clôture de caisse ferme la restauration des éléments annulés à cette
  // date (et son annulation la rouvre) : les fiches déjà chargées portent un
  // drapeau « restaurable » périmé, qui proposerait un bouton voué au refus.
  ref.invalidate(ligneRecetteDetailProvider);
  ref.invalidate(ligneCotisationDetailProvider);
  ref.invalidate(lignePenaliteDetailProvider);
  ref.read(financeRefreshTickProvider.notifier).state++;
}
