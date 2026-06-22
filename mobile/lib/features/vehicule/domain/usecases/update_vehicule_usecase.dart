import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/vehicule.dart';
import '../repositories/vehicule_repository.dart';

class UpdateVehiculeUseCase {
  final VehiculeRepository _repository;
  const UpdateVehiculeUseCase(this._repository);

  Future<Either<Failure, Vehicule>> call(int id, Vehicule vehicule) =>
      _repository.updateVehicule(id, vehicule);
}
