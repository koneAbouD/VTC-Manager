import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/contravention.dart';

abstract interface class ContraventionRepository {
  Future<Either<Failure, List<Contravention>>> getContraventions();
  Future<Either<Failure, Contravention>> getContraventionById(int id);
  Future<Either<Failure, Contravention>> createContravention(
      Contravention contravention);
  Future<Either<Failure, Contravention>> updateContravention(
      int id, Contravention contravention);
  Future<Either<Failure, void>> deleteContravention(int id);
  Future<Either<Failure, Contravention>> payContravention(
      int id, double montantPaye);
}
