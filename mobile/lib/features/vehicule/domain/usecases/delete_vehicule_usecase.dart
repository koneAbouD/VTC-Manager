import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/vehicule_repository.dart';

class DeleteVehiculeUseCase {
  final VehiculeRepository _repository;
  const DeleteVehiculeUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) =>
      _repository.deleteVehicule(id);
}
