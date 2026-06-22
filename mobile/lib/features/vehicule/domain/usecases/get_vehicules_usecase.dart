import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/vehicule.dart';
import '../repositories/vehicule_repository.dart';

class GetVehiculesUseCase {
  final VehiculeRepository _repository;
  const GetVehiculesUseCase(this._repository);

  Future<Either<Failure, List<Vehicule>>> call() => _repository.getVehicules();
}
