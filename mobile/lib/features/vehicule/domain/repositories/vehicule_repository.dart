import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/vehicule.dart';

abstract interface class VehiculeRepository {
  Future<Either<Failure, List<Vehicule>>> getVehicules();
  Future<Either<Failure, Vehicule>> getVehiculeById(int id);
  Future<Either<Failure, Vehicule>> createVehicule(Vehicule vehicule);
  Future<Either<Failure, Vehicule>> updateVehicule(int id, Vehicule vehicule);
  Future<Either<Failure, void>> deleteVehicule(int id);
}
