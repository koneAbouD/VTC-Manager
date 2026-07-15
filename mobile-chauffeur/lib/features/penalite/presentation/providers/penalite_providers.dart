import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/penalite_remote_datasource.dart';
import '../../data/repositories_impl/penalite_repository_impl.dart';
import '../../domain/entities/ligne_penalite.dart';
import '../../domain/repositories/penalite_repository.dart';
import '../../domain/usecases/get_penalites_usecase.dart';

final _penaliteDatasourceProvider = Provider<PenaliteRemoteDatasource>(
  (ref) => PenaliteRemoteDatasource(ref.watch(apiClientProvider)),
);

final penaliteRepositoryProvider = Provider<PenaliteRepository>(
  (ref) => PenaliteRepositoryImpl(ref.watch(_penaliteDatasourceProvider)),
);

final getPenalitesUseCaseProvider = Provider<GetPenalitesUseCase>(
  (ref) => GetPenalitesUseCase(ref.watch(penaliteRepositoryProvider)),
);

final penalitesProvider =
    FutureProvider.autoDispose<List<LignePenalite>>((ref) async {
  final result = await ref.watch(getPenalitesUseCaseProvider).call();
  return result.fold((f) => throw f.message, (r) => r);
});
