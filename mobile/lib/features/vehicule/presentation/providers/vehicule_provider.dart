import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/vehicule_remote_datasource.dart';
import '../../data/models/vehicule_photo_model.dart';
import '../../data/repositories_impl/vehicule_repository_impl.dart';
import '../../domain/entities/vehicule.dart';
import '../../domain/repositories/vehicule_repository.dart';
import '../../domain/usecases/create_vehicule_usecase.dart';
import '../../domain/usecases/delete_vehicule_usecase.dart';
import '../../domain/usecases/get_vehicules_usecase.dart';
import '../../domain/usecases/update_vehicule_usecase.dart';
import 'vehicule_state.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────

final _secureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(),
);

final _apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(_secureStorageProvider)),
);

// ── Datasource → Repository ─────────────────────────────────────────────────

final vehiculeDatasourceProvider = Provider<VehiculeRemoteDatasource>(
  (ref) => VehiculeRemoteDatasource(ref.watch(_apiClientProvider)),
);

final vehiculeRepositoryProvider = Provider<VehiculeRepository>(
  (ref) => VehiculeRepositoryImpl(ref.watch(vehiculeDatasourceProvider)),
);

// ── Use cases ───────────────────────────────────────────────────────────────

final _getVehiculesUseCaseProvider = Provider(
  (ref) => GetVehiculesUseCase(ref.watch(vehiculeRepositoryProvider)),
);
final _createVehiculeUseCaseProvider = Provider(
  (ref) => CreateVehiculeUseCase(ref.watch(vehiculeRepositoryProvider)),
);
final _updateVehiculeUseCaseProvider = Provider(
  (ref) => UpdateVehiculeUseCase(ref.watch(vehiculeRepositoryProvider)),
);
final _deleteVehiculeUseCaseProvider = Provider(
  (ref) => DeleteVehiculeUseCase(ref.watch(vehiculeRepositoryProvider)),
);

// ── Notifier ────────────────────────────────────────────────────────────────

class VehiculeNotifier extends StateNotifier<VehiculeState> {
  final GetVehiculesUseCase _getVehicules;
  final CreateVehiculeUseCase _createVehicule;
  final UpdateVehiculeUseCase _updateVehicule;
  final DeleteVehiculeUseCase _deleteVehicule;

  VehiculeNotifier({
    required GetVehiculesUseCase getVehicules,
    required CreateVehiculeUseCase createVehicule,
    required UpdateVehiculeUseCase updateVehicule,
    required DeleteVehiculeUseCase deleteVehicule,
  })  : _getVehicules = getVehicules,
        _createVehicule = createVehicule,
        _updateVehicule = updateVehicule,
        _deleteVehicule = deleteVehicule,
        super(const VehiculeInitial());

  Future<void> loadVehicules() async {
    state = const VehiculeLoading();
    final result = await _getVehicules.call();
    result.fold(
      (failure) => state = VehiculeError(failure.message),
      (vehicules) => state = VehiculeLoaded(vehicules),
    );
  }

  /// Retourne (message d'erreur, id du véhicule créé).
  Future<(String?, int?)> createVehicule(Vehicule vehicule) async {
    final result = await _createVehicule.call(vehicule);
    return result.fold(
      (failure) => (failure.message, null),
      (created) {
        loadVehicules();
        return (null, created.id);
      },
    );
  }

  /// Retourne (message d'erreur, id du véhicule mis à jour).
  Future<(String?, int?)> updateVehicule(int id, Vehicule vehicule) async {
    final result = await _updateVehicule.call(id, vehicule);
    return result.fold(
      (failure) => (failure.message, null),
      (updated) {
        loadVehicules();
        return (null, updated.id);
      },
    );
  }

  Future<String?> deleteVehicule(int id) async {
    final result = await _deleteVehicule.call(id);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadVehicules();
        return null;
      },
    );
  }
}

// ── Provider GET by ID ──────────────────────────────────────────────────────

final vehiculeByIdProvider =
    FutureProvider.family<Vehicule, int>((ref, id) async {
  final ds = ref.watch(vehiculeDatasourceProvider);
  return ds.getVehiculeById(id);
});

// ── Provider photos ─────────────────────────────────────────────────────────

final vehiculePhotosProvider =
    FutureProvider.family<List<VehiculePhotoModel>, int>((ref, vehiculeId) async {
  final ds = ref.watch(vehiculeDatasourceProvider);
  return ds.getPhotos(vehiculeId);
});

/// Upload une liste de photos après la création/mise à jour du véhicule.
/// Retourne null si tout va bien, sinon le premier message d'erreur.
Future<String?> uploadVehiculePhotos(
  VehiculeRemoteDatasource datasource,
  int vehiculeId,
  List<({Uint8List bytes, String filename})> photos,
) async {
  for (final p in photos) {
    try {
      await datasource.uploadPhoto(vehiculeId, p.bytes, p.filename);
    } catch (e) {
      return 'Erreur upload photo : $e';
    }
  }
  return null;
}

final vehiculeNotifierProvider =
    StateNotifierProvider<VehiculeNotifier, VehiculeState>((ref) {
  return VehiculeNotifier(
    getVehicules: ref.watch(_getVehiculesUseCaseProvider),
    createVehicule: ref.watch(_createVehiculeUseCaseProvider),
    updateVehicule: ref.watch(_updateVehiculeUseCaseProvider),
    deleteVehicule: ref.watch(_deleteVehiculeUseCaseProvider),
  );
});
