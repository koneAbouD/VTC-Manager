import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/contravention_remote_datasource.dart';
import '../../data/repositories_impl/contravention_repository_impl.dart';
import '../../domain/entities/contravention.dart';
import '../../domain/repositories/contravention_repository.dart';
import '../../domain/usecases/get_contraventions_usecase.dart';

final _contraventionDatasourceProvider = Provider<ContraventionRemoteDatasource>(
  (ref) => ContraventionRemoteDatasource(ref.watch(apiClientProvider)),
);

final contraventionRepositoryProvider = Provider<ContraventionRepository>(
  (ref) =>
      ContraventionRepositoryImpl(ref.watch(_contraventionDatasourceProvider)),
);

final getContraventionsUseCaseProvider = Provider<GetContraventionsUseCase>(
  (ref) => GetContraventionsUseCase(ref.watch(contraventionRepositoryProvider)),
);

final contraventionsProvider =
    FutureProvider.autoDispose<List<Contravention>>((ref) async {
  final result = await ref.watch(getContraventionsUseCaseProvider).call();
  return result.fold((f) => throw f.message, (r) => r);
});
