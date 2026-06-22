import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/depense.dart';

abstract interface class DepenseRepository {
  Future<Either<Failure, List<Depense>>> getDepenses();
  Future<Either<Failure, Depense>> getDepenseById(int id);
  Future<Either<Failure, Depense>> createDepense(Depense depense);
  Future<Either<Failure, Depense>> updateDepense(int id, Depense depense);
  Future<Either<Failure, void>> deleteDepense(int id);
}
