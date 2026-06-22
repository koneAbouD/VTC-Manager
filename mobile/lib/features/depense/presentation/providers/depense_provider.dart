import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/depense_remote_datasource.dart';
import '../../data/repositories_impl/depense_repository_impl.dart';
import '../../domain/entities/depense.dart';
import '../../domain/repositories/depense_repository.dart';
import '../../domain/usecases/create_depense_usecase.dart';
import '../../domain/usecases/delete_depense_usecase.dart';
import '../../domain/usecases/get_depenses_usecase.dart';
import '../../domain/usecases/update_depense_usecase.dart';
import 'depense_state.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────

final _secureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(),
);

final _apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(_secureStorageProvider)),
);

// ── Datasource → Repository ─────────────────────────────────────────────────

final _depenseDatasourceProvider = Provider<DepenseRemoteDatasource>(
  (ref) => DepenseRemoteDatasource(ref.watch(_apiClientProvider)),
);

final depenseRepositoryProvider = Provider<DepenseRepository>(
  (ref) => DepenseRepositoryImpl(ref.watch(_depenseDatasourceProvider)),
);

// ── Use cases ───────────────────────────────────────────────────────────────

final _getDepensesUseCaseProvider = Provider(
  (ref) => GetDepensesUseCase(ref.watch(depenseRepositoryProvider)),
);
final _createDepenseUseCaseProvider = Provider(
  (ref) => CreateDepenseUseCase(ref.watch(depenseRepositoryProvider)),
);
final _updateDepenseUseCaseProvider = Provider(
  (ref) => UpdateDepenseUseCase(ref.watch(depenseRepositoryProvider)),
);
final _deleteDepenseUseCaseProvider = Provider(
  (ref) => DeleteDepenseUseCase(ref.watch(depenseRepositoryProvider)),
);

// ── Notifier ────────────────────────────────────────────────────────────────

class DepenseNotifier extends StateNotifier<DepenseState> {
  final GetDepensesUseCase _getDepenses;
  final CreateDepenseUseCase _createDepense;
  final UpdateDepenseUseCase _updateDepense;
  final DeleteDepenseUseCase _deleteDepense;

  DepenseNotifier({
    required GetDepensesUseCase getDepenses,
    required CreateDepenseUseCase createDepense,
    required UpdateDepenseUseCase updateDepense,
    required DeleteDepenseUseCase deleteDepense,
  })  : _getDepenses = getDepenses,
        _createDepense = createDepense,
        _updateDepense = updateDepense,
        _deleteDepense = deleteDepense,
        super(const DepenseInitial());

  Future<void> loadDepenses() async {
    state = const DepenseLoading();
    final result = await _getDepenses.call();
    result.fold(
      (failure) => state = DepenseError(failure.message),
      (depenses) => state = DepenseLoaded(depenses),
    );
  }

  Future<String?> createDepense(Depense depense) async {
    final result = await _createDepense.call(depense);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadDepenses();
        return null;
      },
    );
  }

  Future<String?> updateDepense(int id, Depense depense) async {
    final result = await _updateDepense.call(id, depense);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadDepenses();
        return null;
      },
    );
  }

  Future<String?> deleteDepense(int id) async {
    final result = await _deleteDepense.call(id);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadDepenses();
        return null;
      },
    );
  }
}

final depenseNotifierProvider =
    StateNotifierProvider<DepenseNotifier, DepenseState>((ref) {
  return DepenseNotifier(
    getDepenses: ref.watch(_getDepensesUseCaseProvider),
    createDepense: ref.watch(_createDepenseUseCaseProvider),
    updateDepense: ref.watch(_updateDepenseUseCaseProvider),
    deleteDepense: ref.watch(_deleteDepenseUseCaseProvider),
  );
});
