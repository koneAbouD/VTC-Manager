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

/// Critère de filtrage de la liste « véhicules demandant une action ».
///
/// Filtre purement local : le résumé est déjà chargé, la liste est réduite à
/// l'affichage (aucun appel réseau supplémentaire). Le critère porte sur le
/// motif — ce qui appelle une action —, motif nul = « Tous ».
class ExceptionCritere {
  /// Code motif ciblé (`PANNE_OU_ACCIDENT`, `MAINTENANCE_PREVUE`,
  /// `VIDANGE_DUE`, …).
  final String? motif;

  const ExceptionCritere({this.motif});

  bool get estActif => motif != null;

  bool correspond(VehiculeExceptionModel e) => motif == null || e.motif == motif;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExceptionCritere && other.motif == motif);

  @override
  int get hashCode => motif.hashCode;
}

/// Critère courant de la liste des exceptions. Réinitialisé à « Tous » lorsque
/// le filtre groupe/activité change : le parc affiché n'est plus le même.
final etatParcExceptionCritereProvider =
    StateProvider<ExceptionCritere>((ref) {
  ref.watch(etatParcFiltreProvider);
  return const ExceptionCritere();
});

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
