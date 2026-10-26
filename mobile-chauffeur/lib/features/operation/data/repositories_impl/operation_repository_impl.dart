import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/operation_financiere.dart';
import '../../domain/repositories/operation_repository.dart';
import '../datasources/operation_remote_datasource.dart';

class OperationRepositoryImpl implements OperationRepository {
  final OperationRemoteDatasource _datasource;
  const OperationRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<OperationFinanciere>>> getOperations() =>
      guard(() => _datasource.getOperations());
}
