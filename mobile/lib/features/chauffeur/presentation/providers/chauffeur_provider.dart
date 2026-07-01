import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/chauffeur_remote_datasource.dart';
import '../../data/repositories_impl/chauffeur_repository_impl.dart';
import '../../domain/entities/chauffeur.dart';
import '../../domain/repositories/chauffeur_repository.dart';
import '../../domain/usecases/create_chauffeur_usecase.dart';
import '../../domain/usecases/delete_chauffeur_usecase.dart';
import '../../domain/usecases/get_chauffeurs_usecase.dart';
import '../../domain/usecases/update_chauffeur_usecase.dart';
import 'chauffeur_state.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────

final _secureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(),
);

final _apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(_secureStorageProvider)),
);

// ── Datasource → Repository ─────────────────────────────────────────────────

final chauffeurDatasourceProvider = Provider<ChauffeurRemoteDatasource>(
  (ref) => ChauffeurRemoteDatasource(ref.watch(_apiClientProvider)),
);

final chauffeurRepositoryProvider = Provider<ChauffeurRepository>(
  (ref) => ChauffeurRepositoryImpl(ref.watch(chauffeurDatasourceProvider)),
);

// ── Use cases ───────────────────────────────────────────────────────────────

final _getChauffeursUseCaseProvider = Provider(
  (ref) => GetChauffeursUseCase(ref.watch(chauffeurRepositoryProvider)),
);
final _createChauffeurUseCaseProvider = Provider(
  (ref) => CreateChauffeurUseCase(ref.watch(chauffeurRepositoryProvider)),
);
final _updateChauffeurUseCaseProvider = Provider(
  (ref) => UpdateChauffeurUseCase(ref.watch(chauffeurRepositoryProvider)),
);
final _deleteChauffeurUseCaseProvider = Provider(
  (ref) => DeleteChauffeurUseCase(ref.watch(chauffeurRepositoryProvider)),
);

// ── Notifier ────────────────────────────────────────────────────────────────

class ChauffeurNotifier extends StateNotifier<ChauffeurState> {
  final GetChauffeursUseCase _getChauffeurs;
  final CreateChauffeurUseCase _createChauffeur;
  final UpdateChauffeurUseCase _updateChauffeur;
  final DeleteChauffeurUseCase _deleteChauffeur;

  ChauffeurNotifier({
    required GetChauffeursUseCase getChauffeurs,
    required CreateChauffeurUseCase createChauffeur,
    required UpdateChauffeurUseCase updateChauffeur,
    required DeleteChauffeurUseCase deleteChauffeur,
  })  : _getChauffeurs = getChauffeurs,
        _createChauffeur = createChauffeur,
        _updateChauffeur = updateChauffeur,
        _deleteChauffeur = deleteChauffeur,
        super(const ChauffeurInitial());

  Future<void> loadChauffeurs() async {
    state = const ChauffeurLoading();
    final result = await _getChauffeurs.call();
    result.fold(
      (failure) => state = ChauffeurError(failure.message),
      (chauffeurs) => state = ChauffeurLoaded(chauffeurs),
    );
  }

  Future<String?> createChauffeur(
    Chauffeur chauffeur, {
    Uint8List? permisBytes,
    String permisFilename = 'permis.jpg',
    Uint8List? photoBytes,
    String photoFilename = 'photo.jpg',
    String? numeroPermis,
    List<String>? typesPermis,
    DateTime? dateEmissionPermis,
    DateTime? dateExpirationPermis,
  }) async {
    final result = await _createChauffeur.call(
      chauffeur,
      permisBytes: permisBytes,
      permisFilename: permisFilename,
      photoBytes: photoBytes,
      photoFilename: photoFilename,
      numeroPermis: numeroPermis,
      typesPermis: typesPermis,
      dateEmissionPermis: dateEmissionPermis,
      dateExpirationPermis: dateExpirationPermis,
    );
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadChauffeurs();
        return null;
      },
    );
  }

  Future<String?> updateChauffeur(
    int id,
    Chauffeur chauffeur, {
    Uint8List? permisBytes,
    String permisFilename = 'permis.jpg',
    Uint8List? photoBytes,
    String photoFilename = 'photo.jpg',
    bool deletePhoto = false,
  }) async {
    final result = await _updateChauffeur.call(
      id,
      chauffeur,
      permisBytes: permisBytes,
      permisFilename: permisFilename,
      photoBytes: photoBytes,
      photoFilename: photoFilename,
      deletePhoto: deletePhoto,
    );
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadChauffeurs();
        return null;
      },
    );
  }

  Future<String?> deleteChauffeur(int id) async {
    final result = await _deleteChauffeur.call(id);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadChauffeurs();
        return null;
      },
    );
  }
}

final chauffeurNotifierProvider =
    StateNotifierProvider<ChauffeurNotifier, ChauffeurState>((ref) {
  return ChauffeurNotifier(
    getChauffeurs: ref.watch(_getChauffeursUseCaseProvider),
    createChauffeur: ref.watch(_createChauffeurUseCaseProvider),
    updateChauffeur: ref.watch(_updateChauffeurUseCaseProvider),
    deleteChauffeur: ref.watch(_deleteChauffeurUseCaseProvider),
  );
});

// ── Liste paginée (scroll infini) pour la page Chauffeurs ────────────────────

final chauffeursListeProvider = StateNotifierProvider.autoDispose<
    PagedListNotifier<Chauffeur>, PagedListState<Chauffeur>>(
  (ref) => PagedListNotifier<Chauffeur>(),
);

// ── Provider GET by ID ──────────────────────────────────────────────────────

/// Fournit un chauffeur par son identifiant (appel direct backend, sans cache).
/// L'écran de détail s'en sert pour récupérer la version la plus à jour après
/// une modification.
final chauffeurByIdProvider =
    FutureProvider.autoDispose.family<Chauffeur, int>((ref, id) async {
  final ds = ref.watch(chauffeurDatasourceProvider);
  return ds.getChauffeurById(id);
});

// ── Cache-buster photo ──────────────────────────────────────────────────────

/// Compteur de version par chauffeur ID.
/// Incrémenter ce compteur casse le cache réseau de [ChauffeurAvatar]
/// (l'URL de la photo inclut `?v=<version>`).
final chauffeurPhotoVersionProvider =
    StateProvider<Map<int, int>>((ref) => const {});
