import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/configuration_recette.dart';
import '../repositories/configuration_recette_repository.dart';

class GetConfigurationRecetteUseCase {
  final ConfigurationRecetteRepository _repository;

  const GetConfigurationRecetteUseCase(this._repository);

  Future<Either<Failure, ConfigurationRecette>> call(int vehiculeId) {
    return _repository.getConfiguration(vehiculeId);
  }
}
