import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/operation_remote_datasource.dart';
import '../../data/repositories_impl/operation_repository_impl.dart';
import '../../domain/entities/operation_financiere.dart';
import '../../domain/repositories/operation_repository.dart';
import '../../domain/usecases/get_operations_usecase.dart';

final _operationDatasourceProvider = Provider<OperationRemoteDatasource>(
  (ref) => OperationRemoteDatasource(ref.watch(apiClientProvider)),
);

final operationRepositoryProvider = Provider<OperationRepository>(
  (ref) => OperationRepositoryImpl(ref.watch(_operationDatasourceProvider)),
);

final getOperationsUseCaseProvider = Provider<GetOperationsUseCase>(
  (ref) => GetOperationsUseCase(ref.watch(operationRepositoryProvider)),
);

final operationsProvider =
    FutureProvider.autoDispose<List<OperationFinanciere>>((ref) async {
  final result = await ref.watch(getOperationsUseCaseProvider).call();
  return result.fold((f) => throw f.message, (r) => r);
});
