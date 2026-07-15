import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ligne_cotisation.dart';

abstract interface class CotisationRepository {
  Future<Either<Failure, List<LigneCotisation>>> getCotisations();
}
