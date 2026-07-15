import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ligne_recette.dart';

abstract interface class RecetteRepository {
  Future<Either<Failure, List<LigneRecette>>> getRecettes();
}
