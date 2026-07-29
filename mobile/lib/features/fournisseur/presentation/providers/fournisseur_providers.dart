import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/fournisseur_remote_datasource.dart';
import '../../domain/entities/facture_fournisseur.dart';
import '../../domain/entities/fournisseur.dart';

final fournisseurDatasourceProvider = Provider<FournisseurRemoteDatasource>(
  (ref) => FournisseurRemoteDatasource(ref.watch(apiClientProvider)),
);

/// Fournisseurs actifs, par nom.
final fournisseursProvider =
    FutureProvider.family<List<Fournisseur>, bool>((ref, actifsSeulement) =>
        ref.watch(fournisseurDatasourceProvider).getFournisseurs(
              actifsSeulement: actifsSeulement,
            ));

/// Échéancier : les factures encore dues, la plus ancienne échéance en tête.
final echeancierProvider = FutureProvider.family<List<FactureFournisseur>, int?>(
  (ref, fournisseurId) => ref
      .watch(fournisseurDatasourceProvider)
      .getEcheancier(fournisseurId: fournisseurId),
);

/// Factures reçues sur un mois — la charge de la période, payée ou non.
final facturesDuMoisProvider =
    FutureProvider.family<List<FactureFournisseur>, ({int annee, int mois})>(
  (ref, p) => ref
      .watch(fournisseurDatasourceProvider)
      .getFacturesDuMois(p.annee, p.mois),
);

/// Une facture et son historique de règlements.
final factureProvider = FutureProvider.family<FactureFournisseur, int>(
  (ref, id) => ref.watch(fournisseurDatasourceProvider).getFacture(id),
);

final reglementsFactureProvider =
    FutureProvider.family<List<ReglementFacture>, int>(
  (ref, factureId) =>
      ref.watch(fournisseurDatasourceProvider).getReglements(factureId),
);

/// Recharge tout ce qui touche aux fournisseurs après une écriture.
void refreshFournisseurs(WidgetRef ref) {
  ref.invalidate(fournisseursProvider);
  ref.invalidate(echeancierProvider);
  ref.invalidate(facturesDuMoisProvider);
  ref.invalidate(factureProvider);
  ref.invalidate(reglementsFactureProvider);
}
