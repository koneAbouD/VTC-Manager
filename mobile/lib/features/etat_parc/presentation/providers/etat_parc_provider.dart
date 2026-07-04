import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/etat_parc_remote_datasource.dart';
import '../../data/models/etat_parc_summary_model.dart';

final etatParcDatasourceProvider = Provider<EtatParcRemoteDatasource>(
  (ref) => EtatParcRemoteDatasource(ref.watch(apiClientProvider)),
);

/// Filtre courant de l'état de parc (groupe / activité). Null = « Tous » /
/// « Toutes ». Modifier ce provider recharge automatiquement le résumé.
class EtatParcFiltre {
  final int? groupeId;
  final String? groupeNom;
  final int? activiteId;
  final String? activiteNom;

  const EtatParcFiltre({
    this.groupeId,
    this.groupeNom,
    this.activiteId,
    this.activiteNom,
  });

  String get groupeLabel => groupeNom ?? 'Tous';
  String get activiteLabel => activiteNom ?? 'Toutes';

  bool get estActif => groupeId != null || activiteId != null;

  EtatParcFiltre copyWith({
    int? groupeId,
    String? groupeNom,
    int? activiteId,
    String? activiteNom,
  }) =>
      EtatParcFiltre(
        groupeId: groupeId ?? this.groupeId,
        groupeNom: groupeNom ?? this.groupeNom,
        activiteId: activiteId ?? this.activiteId,
        activiteNom: activiteNom ?? this.activiteNom,
      );
}

final etatParcFiltreProvider =
    StateProvider<EtatParcFiltre>((ref) => const EtatParcFiltre());

/// Photo du parc (lecture seule), cadrée par [etatParcFiltreProvider].
/// Invalider le provider pour rafraîchir.
final etatParcSummaryProvider =
    FutureProvider.autoDispose<EtatParcSummaryModel>((ref) {
  final filtre = ref.watch(etatParcFiltreProvider);
  return ref.watch(etatParcDatasourceProvider).getSummary(
        groupeId: filtre.groupeId,
        activiteId: filtre.activiteId,
      );
});
