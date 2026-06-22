import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/recette_remote_datasource.dart';
import '../../data/repositories_impl/recette_repository_impl.dart';
import '../../domain/entities/recette.dart';
import '../../domain/repositories/recette_repository.dart';
import '../../domain/usecases/create_recette_usecase.dart';
import '../../domain/usecases/delete_recette_usecase.dart';
import '../../domain/usecases/get_recettes_usecase.dart';
import '../../domain/usecases/update_recette_usecase.dart';
import 'recette_state.dart';

// ── Datasource → Repository ─────────────────────────────────────────────────

final _recetteDatasourceProvider = Provider<RecetteRemoteDatasource>(
  (ref) => RecetteRemoteDatasource(ref.watch(apiClientProvider)),
);

final recetteRepositoryProvider = Provider<RecetteRepository>(
  (ref) => RecetteRepositoryImpl(ref.watch(_recetteDatasourceProvider)),
);

// ── Use cases ───────────────────────────────────────────────────────────────

final _getRecettesUseCaseProvider = Provider(
  (ref) => GetRecettesUseCase(ref.watch(recetteRepositoryProvider)),
);
final _createRecetteUseCaseProvider = Provider(
  (ref) => CreateRecetteUseCase(ref.watch(recetteRepositoryProvider)),
);
final _updateRecetteUseCaseProvider = Provider(
  (ref) => UpdateRecetteUseCase(ref.watch(recetteRepositoryProvider)),
);
final _deleteRecetteUseCaseProvider = Provider(
  (ref) => DeleteRecetteUseCase(ref.watch(recetteRepositoryProvider)),
);

// ── Notifier ────────────────────────────────────────────────────────────────

class RecetteNotifier extends StateNotifier<RecetteState> {
  final GetRecettesUseCase _getRecettes;
  final CreateRecetteUseCase _createRecette;
  final UpdateRecetteUseCase _updateRecette;
  final DeleteRecetteUseCase _deleteRecette;

  RecetteNotifier({
    required GetRecettesUseCase getRecettes,
    required CreateRecetteUseCase createRecette,
    required UpdateRecetteUseCase updateRecette,
    required DeleteRecetteUseCase deleteRecette,
  })  : _getRecettes = getRecettes,
        _createRecette = createRecette,
        _updateRecette = updateRecette,
        _deleteRecette = deleteRecette,
        super(const RecetteInitial());

  Future<void> loadRecettes() async {
    state = const RecetteLoading();
    final result = await _getRecettes.call();
    result.fold(
      (failure) => state = RecetteError(failure.message),
      (recettes) => state = RecetteLoaded(recettes),
    );
  }

  Future<String?> createRecette(Recette recette) async {
    final result = await _createRecette.call(recette);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadRecettes();
        return null;
      },
    );
  }

  Future<String?> updateRecette(int id, Recette recette) async {
    final result = await _updateRecette.call(id, recette);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadRecettes();
        return null;
      },
    );
  }

  Future<String?> deleteRecette(int id) async {
    final result = await _deleteRecette.call(id);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadRecettes();
        return null;
      },
    );
  }
}

final recetteNotifierProvider =
    StateNotifierProvider<RecetteNotifier, RecetteState>((ref) {
  return RecetteNotifier(
    getRecettes: ref.watch(_getRecettesUseCaseProvider),
    createRecette: ref.watch(_createRecetteUseCaseProvider),
    updateRecette: ref.watch(_updateRecetteUseCaseProvider),
    deleteRecette: ref.watch(_deleteRecetteUseCaseProvider),
  );
});
