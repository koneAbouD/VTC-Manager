import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/configuration_recette.dart';

abstract interface class ConfigurationRecetteRepository {
  Future<Either<Failure, ConfigurationRecette>> getConfiguration(int vehiculeId);
  Future<Either<Failure, ConfigurationRecette>> createConfiguration(
    int vehiculeId,
    ConfigurationRecette configuration,
  );
  Future<Either<Failure, ConfigurationRecette>> updateConfiguration(
    int vehiculeId,
    ConfigurationRecette configuration,
  );
}
