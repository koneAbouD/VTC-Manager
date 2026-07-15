import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/ligne_recette.dart';
import '../../domain/repositories/recette_repository.dart';
import '../datasources/recette_remote_datasource.dart';

class RecetteRepositoryImpl implements RecetteRepository {
  final RecetteRemoteDatasource _datasource;
  const RecetteRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<LigneRecette>>> getRecettes() =>
      guard(() => _datasource.getRecettes());
}
