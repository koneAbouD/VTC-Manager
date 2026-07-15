import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/recette_remote_datasource.dart';
import '../../data/repositories_impl/recette_repository_impl.dart';
import '../../domain/entities/ligne_recette.dart';
import '../../domain/repositories/recette_repository.dart';
import '../../domain/usecases/get_recettes_usecase.dart';

final _recetteDatasourceProvider = Provider<RecetteRemoteDatasource>(
  (ref) => RecetteRemoteDatasource(ref.watch(apiClientProvider)),
);

final recetteRepositoryProvider = Provider<RecetteRepository>(
  (ref) => RecetteRepositoryImpl(ref.watch(_recetteDatasourceProvider)),
);

final getRecettesUseCaseProvider = Provider<GetRecettesUseCase>(
  (ref) => GetRecettesUseCase(ref.watch(recetteRepositoryProvider)),
);

/// Liste des recettes du chauffeur connecté.
final recettesProvider =
    FutureProvider.autoDispose<List<LigneRecette>>((ref) async {
  final result = await ref.watch(getRecettesUseCaseProvider).call();
  return result.fold((f) => throw f.message, (r) => r);
});
