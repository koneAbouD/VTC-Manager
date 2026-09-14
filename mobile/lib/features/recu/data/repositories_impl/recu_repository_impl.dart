import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/repositories/recu_repository.dart';
import '../datasources/recu_remote_datasource.dart';

class RecuRepositoryImpl implements RecuRepository {
  final RecuRemoteDatasource _datasource;
  const RecuRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, Uint8List>> getRecuPdf(List<int> operationIds) async {
    try {
      return Right(await _datasource.getRecuPdf(operationIds));
    } on ApiException catch (e) {
      return Left(switch (e.statusCode) {
        404 => NotFoundFailure(e.message),
        409 => ConflictFailure(e.message),
        401 || 403 => AuthFailure(e.message),
        _ when e.statusCode >= 400 && e.statusCode < 500 =>
          ValidationFailure(e.message),
        _ => ServerFailure(e.message, statusCode: e.statusCode),
      });
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
