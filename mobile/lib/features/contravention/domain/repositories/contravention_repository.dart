import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/contravention.dart';

abstract interface class ContraventionRepository {
  Future<Either<Failure, List<Contravention>>> getContraventions();

  Future<Either<Failure, PageResult<Contravention>>> getContraventionsPage({
    int page,
    int size,
    int? chauffeurId,
    int? vehiculeId,
  });
  Future<Either<Failure, Contravention>> getContraventionById(int id);
  Future<Either<Failure, Contravention>> createContravention(
      Contravention contravention);
  Future<Either<Failure, Contravention>> updateContravention(
      int id, Contravention contravention);
  Future<Either<Failure, void>> deleteContravention(int id);
  Future<Either<Failure, Contravention>> payContravention(
      int id, double montantPaye);

  /// Reverse la contravention à l'État (crée l'opération de reversement).
  Future<Either<Failure, Contravention>> reverserContravention(int id);
}
