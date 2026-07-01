import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/maintenance_remote_datasource.dart';
import '../../data/repositories_impl/maintenance_repository_impl.dart';
import '../../domain/entities/maintenance.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../domain/usecases/complete_maintenance_usecase.dart';
import '../../domain/usecases/create_maintenance_usecase.dart';
import '../../domain/usecases/delete_maintenance_usecase.dart';
import '../../domain/usecases/get_maintenances_usecase.dart';
import '../../domain/usecases/update_maintenance_usecase.dart';
import 'maintenance_state.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────

final _secureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(),
);

final _apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(_secureStorageProvider)),
);

// ── Datasource → Repository ─────────────────────────────────────────────────

final _maintenanceDatasourceProvider = Provider<MaintenanceRemoteDatasource>(
  (ref) => MaintenanceRemoteDatasource(ref.watch(_apiClientProvider)),
);

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) =>
      MaintenanceRepositoryImpl(ref.watch(_maintenanceDatasourceProvider)),
);

// ── Use cases ───────────────────────────────────────────────────────────────

final _getMaintenancesUseCaseProvider = Provider(
  (ref) => GetMaintenancesUseCase(ref.watch(maintenanceRepositoryProvider)),
);
final _createMaintenanceUseCaseProvider = Provider(
  (ref) =>
      CreateMaintenanceUseCase(ref.watch(maintenanceRepositoryProvider)),
);
final _updateMaintenanceUseCaseProvider = Provider(
  (ref) =>
      UpdateMaintenanceUseCase(ref.watch(maintenanceRepositoryProvider)),
);
final _deleteMaintenanceUseCaseProvider = Provider(
  (ref) =>
      DeleteMaintenanceUseCase(ref.watch(maintenanceRepositoryProvider)),
);
final _completeMaintenanceUseCaseProvider = Provider(
  (ref) =>
      CompleteMaintenanceUseCase(ref.watch(maintenanceRepositoryProvider)),
);

// ── Notifier ────────────────────────────────────────────────────────────────

class MaintenanceNotifier extends StateNotifier<MaintenanceState> {
  final GetMaintenancesUseCase _getMaintenances;
  final CreateMaintenanceUseCase _createMaintenance;
  final UpdateMaintenanceUseCase _updateMaintenance;
  final DeleteMaintenanceUseCase _deleteMaintenance;
  final CompleteMaintenanceUseCase _completeMaintenance;

  MaintenanceNotifier({
    required GetMaintenancesUseCase getMaintenances,
    required CreateMaintenanceUseCase createMaintenance,
    required UpdateMaintenanceUseCase updateMaintenance,
    required DeleteMaintenanceUseCase deleteMaintenance,
    required CompleteMaintenanceUseCase completeMaintenance,
  })  : _getMaintenances = getMaintenances,
        _createMaintenance = createMaintenance,
        _updateMaintenance = updateMaintenance,
        _deleteMaintenance = deleteMaintenance,
        _completeMaintenance = completeMaintenance,
        super(const MaintenanceInitial());

  Future<void> loadMaintenances() async {
    state = const MaintenanceLoading();
    final result = await _getMaintenances.call();
    result.fold(
      (failure) => state = MaintenanceError(failure.message),
      (maintenances) => state = MaintenanceLoaded(maintenances),
    );
  }

  Future<void> loadByPeriode({
    required String dateDebut,
    required String dateFin,
    String? statut,
  }) async {
    state = const MaintenanceLoading();
    final result = await _getMaintenances.call(
      dateDebut: dateDebut,
      dateFin: dateFin,
      statut: statut,
    );
    result.fold(
      (failure) => state = MaintenanceError(failure.message),
      (maintenances) => state = MaintenanceLoaded(maintenances),
    );
  }

  Future<String?> createMaintenance(Maintenance maintenance) async {
    final result = await _createMaintenance.call(maintenance);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadMaintenances();
        return null;
      },
    );
  }

  Future<String?> updateMaintenance(int id, Maintenance maintenance) async {
    final result = await _updateMaintenance.call(id, maintenance);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadMaintenances();
        return null;
      },
    );
  }

  Future<String?> deleteMaintenance(int id) async {
    final result = await _deleteMaintenance.call(id);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadMaintenances();
        return null;
      },
    );
  }

  Future<String?> completeMaintenance(int id, double cout) async {
    final result = await _completeMaintenance.call(id, cout);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadMaintenances();
        return null;
      },
    );
  }
}

// ── Liste paginée (scroll infini) pour la page Maintenances ──────────────────

final maintenancesListeProvider = StateNotifierProvider.autoDispose<
    PagedListNotifier<Maintenance>, PagedListState<Maintenance>>(
  (ref) => PagedListNotifier<Maintenance>(),
);

final maintenanceNotifierProvider =
    StateNotifierProvider<MaintenanceNotifier, MaintenanceState>((ref) {
  return MaintenanceNotifier(
    getMaintenances: ref.watch(_getMaintenancesUseCaseProvider),
    createMaintenance: ref.watch(_createMaintenanceUseCaseProvider),
    updateMaintenance: ref.watch(_updateMaintenanceUseCaseProvider),
    deleteMaintenance: ref.watch(_deleteMaintenanceUseCaseProvider),
    completeMaintenance: ref.watch(_completeMaintenanceUseCaseProvider),
  );
});
