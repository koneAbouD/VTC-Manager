import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/versement_remote_datasource.dart';
import '../../data/repositories_impl/versement_repository_impl.dart';
import '../../domain/entities/versement.dart';
import '../../domain/repositories/versement_repository.dart';

final _versementDatasourceProvider = Provider<VersementRemoteDatasource>(
  (ref) => VersementRemoteDatasource(ref.watch(apiClientProvider)),
);

final versementRepositoryProvider = Provider<VersementRepository>(
  (ref) => VersementRepositoryImpl(ref.watch(_versementDatasourceProvider)),
);

/// Une pièce de caisse, relue au serveur : le détail d'une écriture et le reçu
/// en ont besoin pour connaître la sœur et ce qui reste dû.
final versementProvider =
    FutureProvider.autoDispose.family<Versement, String>((ref, id) async {
  final result = await ref.watch(versementRepositoryProvider).getVersement(id);
  return result.fold((f) => throw Exception(f.message), (v) => v);
});
