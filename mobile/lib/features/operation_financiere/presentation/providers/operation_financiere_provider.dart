import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/operation_financiere_remote_datasource.dart';
import '../../data/repositories_impl/operation_financiere_repository_impl.dart';
import '../../domain/entities/operation_financiere.dart';
import '../../domain/repositories/operation_financiere_repository.dart';
import '../../domain/usecases/annuler_operation_financiere_usecase.dart';
import '../../domain/usecases/create_operation_financiere_usecase.dart';
import '../../domain/usecases/delete_operation_financiere_usecase.dart';
import '../../domain/usecases/get_operations_financieres_usecase.dart';
import '../../domain/usecases/update_operation_financiere_usecase.dart';
import '../../domain/usecases/valider_operation_financiere_usecase.dart';
import 'operation_financiere_state.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────

final _secureStorageProvider =
    Provider<SecureStorage>((_) => const SecureStorage());

final _apiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_secureStorageProvider)));

// ── Datasource → Repository ────────────────────────────────────────────────

final _opDatasourceProvider =
    Provider<OperationFinanciereRemoteDatasource>((ref) =>
        OperationFinanciereRemoteDatasource(ref.watch(_apiClientProvider)));

final operationFinanciereRepositoryProvider =
    Provider<OperationFinanciereRepository>((ref) =>
        OperationFinanciereRepositoryImpl(ref.watch(_opDatasourceProvider)));

// ── Use Cases ──────────────────────────────────────────────────────────────

final _getOpUCProvider = Provider((ref) =>
    GetOperationsFinancieresUseCase(
        ref.watch(operationFinanciereRepositoryProvider)));

final _createOpUCProvider = Provider((ref) =>
    CreateOperationFinanciereUseCase(
        ref.watch(operationFinanciereRepositoryProvider)));

final _updateOpUCProvider = Provider((ref) =>
    UpdateOperationFinanciereUseCase(
        ref.watch(operationFinanciereRepositoryProvider)));

final _deleteOpUCProvider = Provider((ref) =>
    DeleteOperationFinanciereUseCase(
        ref.watch(operationFinanciereRepositoryProvider)));

final _validerOpUCProvider = Provider((ref) =>
    ValiderOperationFinanciereUseCase(
        ref.watch(operationFinanciereRepositoryProvider)));

final _annulerOpUCProvider = Provider((ref) =>
    AnnulerOperationFinanciereUseCase(
        ref.watch(operationFinanciereRepositoryProvider)));

// ── Notifier ───────────────────────────────────────────────────────────────

class OperationFinanciereNotifier
    extends StateNotifier<OperationFinanciereState> {
  final GetOperationsFinancieresUseCase _getAll;
  final CreateOperationFinanciereUseCase _create;
  final UpdateOperationFinanciereUseCase _update;
  final DeleteOperationFinanciereUseCase _delete;
  final ValiderOperationFinanciereUseCase _valider;
  final AnnulerOperationFinanciereUseCase _annuler;

  OperationFinanciereNotifier({
    required GetOperationsFinancieresUseCase getAll,
    required CreateOperationFinanciereUseCase create,
    required UpdateOperationFinanciereUseCase update,
    required DeleteOperationFinanciereUseCase delete,
    required ValiderOperationFinanciereUseCase valider,
    required AnnulerOperationFinanciereUseCase annuler,
  })  : _getAll = getAll,
        _create = create,
        _update = update,
        _delete = delete,
        _valider = valider,
        _annuler = annuler,
        super(const OperationFinanciereInitial());

  List<OperationFinanciere> _current() {
    final s = state;
    return switch (s) {
      OperationFinanciereLoaded(:final operations) => operations,
      OperationFinanciereActionSuccess(:final operations) => operations,
      _ => [],
    };
  }

  Future<void> loadAll({
    String? typeOperation,
    String? categorieCode,
    String? debut,
    String? fin,
    String? statut,
  }) async {
    state = const OperationFinanciereLoading();
    final result = await _getAll(
      typeOperation: typeOperation,
      categorieCode: categorieCode,
      debut:  debut,
      fin:    fin,
      statut: statut,
    );
    result.fold(
      (f) => state = OperationFinanciereError(f.message),
      (ops) => state = OperationFinanciereLoaded(ops),
    );
  }

  Future<String?> create(Map<String, dynamic> payload) async {
    final result = await _create(payload);
    return result.fold(
      (f) => f.message,
      (_) {
        loadAll();
        return null;
      },
    );
  }

  Future<String?> update(int id, Map<String, dynamic> payload) async {
    final result = await _update(id, payload);
    return result.fold(
      (f) => f.message,
      (_) {
        loadAll();
        return null;
      },
    );
  }

  Future<String?> delete(int id) async {
    final result = await _delete(id);
    return result.fold(
      (f) => f.message,
      (_) {
        final updated = _current().where((o) => o.id != id).toList();
        state = OperationFinanciereActionSuccess(updated, 'Opération supprimée');
        return null;
      },
    );
  }

  Future<String?> valider(int id) async {
    final result = await _valider(id);
    return result.fold(
      (f) => f.message,
      (_) {
        loadAll();
        return null;
      },
    );
  }

  Future<String?> annuler(int id) async {
    final result = await _annuler(id);
    return result.fold(
      (f) => f.message,
      (_) {
        loadAll();
        return null;
      },
    );
  }
}

final operationFinanciereNotifierProvider =
    StateNotifierProvider<OperationFinanciereNotifier,
        OperationFinanciereState>((ref) {
  return OperationFinanciereNotifier(
    getAll: ref.watch(_getOpUCProvider),
    create: ref.watch(_createOpUCProvider),
    update: ref.watch(_updateOpUCProvider),
    delete: ref.watch(_deleteOpUCProvider),
    valider: ref.watch(_validerOpUCProvider),
    annuler: ref.watch(_annulerOpUCProvider),
  );
});
