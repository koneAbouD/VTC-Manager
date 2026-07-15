import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/cotisation_remote_datasource.dart';
import '../../data/repositories_impl/cotisation_repository_impl.dart';
import '../../domain/entities/ligne_cotisation.dart';
import '../../domain/repositories/cotisation_repository.dart';
import '../../domain/usecases/get_cotisations_usecase.dart';

final _cotisationDatasourceProvider = Provider<CotisationRemoteDatasource>(
  (ref) => CotisationRemoteDatasource(ref.watch(apiClientProvider)),
);

final cotisationRepositoryProvider = Provider<CotisationRepository>(
  (ref) => CotisationRepositoryImpl(ref.watch(_cotisationDatasourceProvider)),
);

final getCotisationsUseCaseProvider = Provider<GetCotisationsUseCase>(
  (ref) => GetCotisationsUseCase(ref.watch(cotisationRepositoryProvider)),
);

final cotisationsProvider =
    FutureProvider.autoDispose<List<LigneCotisation>>((ref) async {
  final result = await ref.watch(getCotisationsUseCaseProvider).call();
  return result.fold((f) => throw f.message, (r) => r);
});
