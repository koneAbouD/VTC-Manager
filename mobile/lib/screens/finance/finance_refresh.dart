import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/tresorerie/presentation/providers/tresorerie_providers.dart';
import 'rapport_financier_page.dart';

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
  ref.invalidate(rapportFinancierProvider);
  ref.read(financeRefreshTickProvider.notifier).state++;
}
