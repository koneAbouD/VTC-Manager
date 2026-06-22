import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/configuration_recette.dart';
import '../repositories/configuration_recette_repository.dart';

class CreateConfigurationRecetteUseCase {
  final ConfigurationRecetteRepository _repository;

  const CreateConfigurationRecetteUseCase(this._repository);

  Future<Either<Failure, ConfigurationRecette>> call(
    int vehiculeId,
    ConfigurationRecette configuration,
  ) {
    return _repository.createConfiguration(vehiculeId, configuration);
  }
}
