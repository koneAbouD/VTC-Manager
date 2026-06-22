import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../chauffeur/domain/entities/chauffeur.dart';
import '../../../chauffeur/presentation/providers/chauffeur_provider.dart';
import '../../data/datasources/programme_travail_remote_datasource.dart';
import '../../data/repositories_impl/programme_travail_repository_impl.dart';
import '../../domain/entities/programme_travail.dart';
import '../../domain/repositories/programme_travail_repository.dart';
import '../../domain/usecases/create_programme_travail_usecase.dart';
import '../../domain/usecases/get_programme_travail_usecase.dart';
import '../../domain/usecases/invert_programme_travail_usecase.dart';
import '../../domain/usecases/update_programme_travail_usecase.dart';

final _secureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(),
);

final _apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(_secureStorageProvider)),
);

final _programmeTravailDatasourceProvider =
    Provider<ProgrammeTravailRemoteDatasource>(
  (ref) => ProgrammeTravailRemoteDatasource(ref.watch(_apiClientProvider)),
);

final programmeTravailRepositoryProvider = Provider<ProgrammeTravailRepository>(
  (ref) => ProgrammeTravailRepositoryImpl(
    ref.watch(_programmeTravailDatasourceProvider),
  ),
);

final _getProgrammeTravailUseCaseProvider = Provider(
  (ref) => GetProgrammeTravailUseCase(
    ref.watch(programmeTravailRepositoryProvider),
  ),
);

final _createProgrammeTravailUseCaseProvider = Provider(
  (ref) => CreateProgrammeTravailUseCase(
    ref.watch(programmeTravailRepositoryProvider),
  ),
);

final _updateProgrammeTravailUseCaseProvider = Provider(
  (ref) => UpdateProgrammeTravailUseCase(
    ref.watch(programmeTravailRepositoryProvider),
  ),
);

final _invertProgrammeTravailUseCaseProvider = Provider(
  (ref) => InvertProgrammeTravailUseCase(
    ref.watch(programmeTravailRepositoryProvider),
  ),
);

final programmeTravailByVehiculeIdProvider =
    FutureProvider.family<ProgrammeTravail, int>((ref, vehiculeId) async {
  final result =
      await ref.watch(_getProgrammeTravailUseCaseProvider).call(vehiculeId);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (programme) => programme,
  );
});

final activeChauffeursProvider = FutureProvider<List<Chauffeur>>((ref) async {
  final datasource = ref.watch(chauffeurDatasourceProvider);
  final chauffeurs = await datasource.getChauffeurs();
  final actifs = chauffeurs.where((c) => c.isActif).toList();
  actifs.sort((a, b) => a.fullName.compareTo(b.fullName));
  return actifs;
});

class ProgrammeTravailController {
  final Ref _ref;
  final CreateProgrammeTravailUseCase _createUseCase;
  final UpdateProgrammeTravailUseCase _updateUseCase;
  final InvertProgrammeTravailUseCase _invertUseCase;

  const ProgrammeTravailController({
    required Ref ref,
    required CreateProgrammeTravailUseCase createUseCase,
    required UpdateProgrammeTravailUseCase updateUseCase,
    required InvertProgrammeTravailUseCase invertUseCase,
  })  : _ref = ref,
        _createUseCase = createUseCase,
        _updateUseCase = updateUseCase,
        _invertUseCase = invertUseCase;

  /// Retourne :
  /// - `null` si succès
  /// - `ChauffeurConflictFailure` si un chauffeur est déjà affecté ailleurs
  /// - `String` (message d'erreur) pour toute autre erreur
  Future<Object?> saveProgramme(
    int vehiculeId,
    ProgrammeTravail programme, {
    bool force = false,
  }) async {
    final result = programme.isNew
        ? await _createUseCase.call(vehiculeId, programme, force: force)
        : await _updateUseCase.call(vehiculeId, programme, force: force);

    return result.fold(
      (failure) => failure is ChauffeurConflictFailure ? failure : failure.message,
      (_) {
        _ref.invalidate(programmeTravailByVehiculeIdProvider(vehiculeId));
        return null;
      },
    );
  }

  Future<String?> invertProgramme(int vehiculeId) async {
    final result = await _invertUseCase.call(vehiculeId);
    return result.fold(
      (failure) => failure.message,
      (_) {
        _ref.invalidate(programmeTravailByVehiculeIdProvider(vehiculeId));
        return null;
      },
    );
  }
}

final programmeTravailControllerProvider = Provider<ProgrammeTravailController>(
  (ref) => ProgrammeTravailController(
    ref: ref,
    createUseCase: ref.watch(_createProgrammeTravailUseCaseProvider),
    updateUseCase: ref.watch(_updateProgrammeTravailUseCaseProvider),
    invertUseCase: ref.watch(_invertProgrammeTravailUseCaseProvider),
  ),
);
