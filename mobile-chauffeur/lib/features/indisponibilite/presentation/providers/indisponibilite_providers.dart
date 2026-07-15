import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/indisponibilite_remote_datasource.dart';
import '../../data/repositories_impl/indisponibilite_repository_impl.dart';
import '../../domain/entities/indisponibilite.dart';
import '../../domain/entities/remplacant.dart';
import '../../domain/repositories/indisponibilite_repository.dart';
import '../../domain/usecases/declarer_indisponibilite_usecase.dart';
import '../../domain/usecases/get_indisponibilites_usecase.dart';
import '../../domain/usecases/get_remplacants_usecase.dart';
import '../../domain/usecases/terminer_indisponibilite_usecase.dart';

final _indispoDatasourceProvider = Provider<IndisponibiliteRemoteDatasource>(
  (ref) => IndisponibiliteRemoteDatasource(ref.watch(apiClientProvider)),
);

final indisponibiliteRepositoryProvider = Provider<IndisponibiliteRepository>(
  (ref) => IndisponibiliteRepositoryImpl(ref.watch(_indispoDatasourceProvider)),
);

final getIndisponibilitesUseCaseProvider = Provider(
  (ref) =>
      GetIndisponibilitesUseCase(ref.watch(indisponibiliteRepositoryProvider)),
);
final getRemplacantsUseCaseProvider = Provider(
  (ref) => GetRemplacantsUseCase(ref.watch(indisponibiliteRepositoryProvider)),
);
final declarerIndisponibiliteUseCaseProvider = Provider(
  (ref) =>
      DeclarerIndisponibiliteUseCase(ref.watch(indisponibiliteRepositoryProvider)),
);
final terminerIndisponibiliteUseCaseProvider = Provider(
  (ref) =>
      TerminerIndisponibiliteUseCase(ref.watch(indisponibiliteRepositoryProvider)),
);

/// Liste des indisponibilités du chauffeur.
final indisponibilitesProvider =
    FutureProvider.autoDispose<List<Indisponibilite>>((ref) async {
  final result = await ref.watch(getIndisponibilitesUseCaseProvider).call();
  return result.fold((f) => throw f.message, (r) => r);
});

/// Liste des remplaçants sélectionnables.
final remplacantsProvider =
    FutureProvider.autoDispose<List<Remplacant>>((ref) async {
  final result = await ref.watch(getRemplacantsUseCaseProvider).call();
  return result.fold((f) => throw f.message, (r) => r);
});
