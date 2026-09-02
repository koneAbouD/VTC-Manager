import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/coherence_remote_datasource.dart';
import '../../domain/entities/conflit_chauffeur.dart';

final _coherenceDatasourceProvider = Provider<CoherenceRemoteDatasource>(
  (ref) => CoherenceRemoteDatasource(ref.watch(apiClientProvider)),
);

/// La période à contrôler, telle que l'écran l'affiche.
class PlageCoherence {
  final DateTime debut;
  final DateTime fin;

  const PlageCoherence(this.debut, this.fin);

  @override
  bool operator ==(Object other) =>
      other is PlageCoherence && other.debut == debut && other.fin == fin;

  @override
  int get hashCode => Object.hash(debut, fin);
}

/// Anomalies relevées sur la période affichée.
///
/// `autoDispose` : le relevé change dès qu'une créance est annulée ou
/// réaffectée, et un bandeau qui survivrait à sa correction signalerait un
/// problème déjà réglé. En cas d'échec, la liste est vide plutôt que remontée :
/// un contrôle de cohérence indisponible ne doit pas barrer l'écran Recettes.
final conflitsChauffeurProvider = FutureProvider.autoDispose
    .family<List<ConflitChauffeur>, PlageCoherence>((ref, plage) async {
  try {
    return await ref
        .watch(_coherenceDatasourceProvider)
        .getConflitsChauffeur(plage.debut, plage.fin);
  } catch (_) {
    return const [];
  }
});
