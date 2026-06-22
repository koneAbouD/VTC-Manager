import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/vehicule.dart';
import '../repositories/vehicule_repository.dart';

class GetVehiculeByIdUseCase {
  final VehiculeRepository _repository;
  const GetVehiculeByIdUseCase(this._repository);

  Future<Either<Failure, Vehicule>> call(int id) =>
      _repository.getVehiculeById(id);
}
