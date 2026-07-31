import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/partenaire_remote_datasource.dart';
import '../../domain/entities/facture_partenaire.dart';
import '../../domain/entities/partenaire.dart';
import '../../domain/entities/type_partenaire.dart';

final partenaireDatasourceProvider = Provider<PartenaireRemoteDatasource>(
  (ref) => PartenaireRemoteDatasource(ref.watch(apiClientProvider)),
);

/// Types de partenaire actifs, alimentés par les données de référence.
final typesPartenaireProvider = FutureProvider<List<TypePartenaire>>(
  (ref) => ref.watch(partenaireDatasourceProvider).getTypesPartenaire(),
);

/// Partenaires actifs, par nom.
final partenairesProvider = FutureProvider.family<List<Partenaire>, bool>(
    (ref, actifsSeulement) =>
        ref.watch(partenaireDatasourceProvider).getPartenaires(
              actifsSeulement: actifsSeulement,
            ));

/// Échéancier : les factures encore dues, la plus ancienne échéance en tête.
final echeancierProvider = FutureProvider.family<List<FacturePartenaire>, int?>(
  (ref, partenaireId) => ref
      .watch(partenaireDatasourceProvider)
      .getEcheancier(partenaireId: partenaireId),
);

/// Factures reçues sur un mois — la charge de la période, payée ou non.
final facturesDuMoisProvider =
    FutureProvider.family<List<FacturePartenaire>, ({int annee, int mois})>(
  (ref, p) => ref
      .watch(partenaireDatasourceProvider)
      .getFacturesDuMois(p.annee, p.mois),
);

/// Dettes nées d'une intervention : ce que l'atelier a laissé à payer.
final facturesDeMaintenanceProvider =
    FutureProvider.family<List<FacturePartenaire>, int>(
  (ref, maintenanceId) => ref
      .watch(partenaireDatasourceProvider)
      .getFacturesDeMaintenance(maintenanceId),
);

/// Une facture et son historique de règlements.
final factureProvider = FutureProvider.family<FacturePartenaire, int>(
  (ref, id) => ref.watch(partenaireDatasourceProvider).getFacture(id),
);

final reglementsFactureProvider =
    FutureProvider.family<List<ReglementFacture>, int>(
  (ref, factureId) =>
      ref.watch(partenaireDatasourceProvider).getReglements(factureId),
);

/// Recharge tout ce qui touche aux partenaires après une écriture.
void refreshPartenaires(WidgetRef ref) {
  ref.invalidate(typesPartenaireProvider);
  ref.invalidate(partenairesProvider);
  ref.invalidate(echeancierProvider);
  ref.invalidate(facturesDeMaintenanceProvider);
  ref.invalidate(facturesDuMoisProvider);
  ref.invalidate(factureProvider);
  ref.invalidate(reglementsFactureProvider);
}
