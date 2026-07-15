import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/contravention.dart';

abstract interface class ContraventionRepository {
  Future<Either<Failure, List<Contravention>>> getContraventions();
}
