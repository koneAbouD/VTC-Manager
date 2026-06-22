import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/configuration_recette.dart';
import '../repositories/configuration_recette_repository.dart';

class UpdateConfigurationRecetteUseCase {
  final ConfigurationRecetteRepository _repository;

  const UpdateConfigurationRecetteUseCase(this._repository);

  Future<Either<Failure, ConfigurationRecette>> call(
    int vehiculeId,
    ConfigurationRecette configuration,
  ) {
    return _repository.updateConfiguration(vehiculeId, configuration);
  }
}
