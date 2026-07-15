import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/ligne_penalite.dart';
import '../../domain/repositories/penalite_repository.dart';
import '../datasources/penalite_remote_datasource.dart';

class PenaliteRepositoryImpl implements PenaliteRepository {
  final PenaliteRemoteDatasource _datasource;
  const PenaliteRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<LignePenalite>>> getPenalites() =>
      guard(() => _datasource.getPenalites());
}
