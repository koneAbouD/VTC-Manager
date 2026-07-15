import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ligne_penalite.dart';

abstract interface class PenaliteRepository {
  Future<Either<Failure, List<LignePenalite>>> getPenalites();
}
