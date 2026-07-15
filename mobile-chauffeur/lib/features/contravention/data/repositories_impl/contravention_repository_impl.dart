import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/contravention.dart';
import '../../domain/repositories/contravention_repository.dart';
import '../datasources/contravention_remote_datasource.dart';

class ContraventionRepositoryImpl implements ContraventionRepository {
  final ContraventionRemoteDatasource _datasource;
  const ContraventionRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<Contravention>>> getContraventions() =>
      guard(() => _datasource.getContraventions());
}
