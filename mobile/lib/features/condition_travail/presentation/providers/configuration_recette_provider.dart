import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/configuration_recette_remote_datasource.dart';
import '../../data/repositories_impl/configuration_recette_repository_impl.dart';
import '../../domain/entities/configuration_recette.dart';
import '../../domain/repositories/configuration_recette_repository.dart';
import '../../domain/usecases/create_configuration_recette_usecase.dart';
import '../../domain/usecases/get_configuration_recette_usecase.dart';
import '../../domain/usecases/update_configuration_recette_usecase.dart';

final _secureStorageConfigurationRecetteProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(),
);

final _apiClientConfigurationRecetteProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(_secureStorageConfigurationRecetteProvider)),
);

final _configurationRecetteDatasourceProvider =
    Provider<ConfigurationRecetteRemoteDatasource>(
  (ref) => ConfigurationRecetteRemoteDatasource(
    ref.watch(_apiClientConfigurationRecetteProvider),
  ),
);

final configurationRecetteRepositoryProvider =
    Provider<ConfigurationRecetteRepository>(
  (ref) => ConfigurationRecetteRepositoryImpl(
    ref.watch(_configurationRecetteDatasourceProvider),
  ),
);

final _getConfigurationRecetteUseCaseProvider = Provider(
  (ref) => GetConfigurationRecetteUseCase(
    ref.watch(configurationRecetteRepositoryProvider),
  ),
);

final _createConfigurationRecetteUseCaseProvider = Provider(
  (ref) => CreateConfigurationRecetteUseCase(
    ref.watch(configurationRecetteRepositoryProvider),
  ),
);

final _updateConfigurationRecetteUseCaseProvider = Provider(
  (ref) => UpdateConfigurationRecetteUseCase(
    ref.watch(configurationRecetteRepositoryProvider),
  ),
);

final configurationRecetteByVehiculeIdProvider =
    FutureProvider.family<ConfigurationRecette, int>((ref, vehiculeId) async {
  final result =
      await ref.watch(_getConfigurationRecetteUseCaseProvider).call(vehiculeId);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (configuration) => configuration,
  );
});

class ConfigurationRecetteController {
  final Ref _ref;
  final CreateConfigurationRecetteUseCase _createUseCase;
  final UpdateConfigurationRecetteUseCase _updateUseCase;

  const ConfigurationRecetteController({
    required Ref ref,
    required CreateConfigurationRecetteUseCase createUseCase,
    required UpdateConfigurationRecetteUseCase updateUseCase,
  })  : _ref = ref,
        _createUseCase = createUseCase,
        _updateUseCase = updateUseCase;

  Future<String?> saveConfiguration(
    int vehiculeId,
    ConfigurationRecette configuration,
  ) async {
    final result = configuration.isNew
        ? await _createUseCase.call(vehiculeId, configuration)
        : await _updateUseCase.call(vehiculeId, configuration);

    return result.fold(
      (failure) => failure.message,
      (_) {
        _ref.invalidate(configurationRecetteByVehiculeIdProvider(vehiculeId));
        return null;
      },
    );
  }
}

final configurationRecetteControllerProvider =
    Provider<ConfigurationRecetteController>(
  (ref) => ConfigurationRecetteController(
    ref: ref,
    createUseCase: ref.watch(_createConfigurationRecetteUseCaseProvider),
    updateUseCase: ref.watch(_updateConfigurationRecetteUseCaseProvider),
  ),
);
