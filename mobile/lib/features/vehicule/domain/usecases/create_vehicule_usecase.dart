import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/vehicule.dart';
import '../repositories/vehicule_repository.dart';

class CreateVehiculeUseCase {
  final VehiculeRepository _repository;
  const CreateVehiculeUseCase(this._repository);

  Future<Either<Failure, Vehicule>> call(Vehicule vehicule) =>
      _repository.createVehicule(vehicule);
}
