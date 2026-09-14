import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/recu_remote_datasource.dart';
import '../../data/repositories_impl/recu_repository_impl.dart';
import '../../domain/repositories/recu_repository.dart';

final _recuDatasourceProvider = Provider<RecuRemoteDatasource>(
  (ref) => RecuRemoteDatasource(ref.watch(apiClientProvider)),
);

final recuRepositoryProvider = Provider<RecuRepository>(
  (ref) => RecuRepositoryImpl(ref.watch(_recuDatasourceProvider)),
);
