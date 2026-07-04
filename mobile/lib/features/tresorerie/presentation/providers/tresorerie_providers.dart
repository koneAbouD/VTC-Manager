import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/tresorerie_remote_datasource.dart';
import '../../domain/entities/compte_tresorerie.dart';
import '../../domain/entities/creance.dart';
import '../../domain/entities/rapports.dart';

final tresorerieDatasourceProvider = Provider<TresorerieRemoteDatasource>(
  (ref) => TresorerieRemoteDatasource(ref.watch(apiClientProvider)),
);
final _tresorerieDatasourceProvider = tresorerieDatasourceProvider;

/// Soldes des comptes + total + montant à reverser à l'État.
final tresorerieSummaryProvider = FutureProvider<TresorerieSummary>(
  (ref) => ref.watch(_tresorerieDatasourceProvider).getSummary(),
);

/// Balance âgée par chauffeur, triée par total décroissant (côté backend).
final balanceAgeeProvider = FutureProvider<List<CreanceChauffeur>>(
  (ref) => ref.watch(_tresorerieDatasourceProvider).getBalanceAgee(),
);

/// Documents ouverts d'un chauffeur, du plus ancien au plus récent.
final creancesChauffeurProvider =
    FutureProvider.family<List<LigneCreance>, int>(
  (ref, chauffeurId) =>
      ref.watch(_tresorerieDatasourceProvider).getCreancesChauffeur(chauffeurId),
);

/// Compte de résultat en cascade pour (mois, annee, base CAISSE|ENGAGEMENT).
final compteResultatProvider = FutureProvider.family<CompteResultatData,
    ({int annee, int mois, String base})>(
  (ref, p) => ref
      .watch(_tresorerieDatasourceProvider)
      .getCompteResultat(annee: p.annee, mois: p.mois, base: p.base),
);

/// Marge sur coûts variables par véhicule pour (mois, annee).
final margesVehiculesProvider = FutureProvider.family<List<MargeVehiculeData>,
    ({int annee, int mois})>(
  (ref, p) => ref
      .watch(_tresorerieDatasourceProvider)
      .getMargesParVehicule(annee: p.annee, mois: p.mois),
);

/// Bilan de gestion à aujourd'hui.
final bilanProvider = FutureProvider<BilanData>(
  (ref) => ref.watch(_tresorerieDatasourceProvider).getBilan(),
);

/// Périodes comptables clôturées (la plus récente en premier).
final cloturesPeriodeProvider = FutureProvider<List<CloturePeriodeData>>(
  (ref) => ref.watch(_tresorerieDatasourceProvider).getCloturesPeriode(),
);
