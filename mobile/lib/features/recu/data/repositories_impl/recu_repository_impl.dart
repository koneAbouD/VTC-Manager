import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/recu_ecritures.dart';
import '../../domain/repositories/recu_repository.dart';
import '../models/recu_ecritures_model.dart';
import '../datasources/recu_remote_datasource.dart';

class RecuRepositoryImpl implements RecuRepository {
  final RecuRemoteDatasource _datasource;
  const RecuRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, Uint8List>> getRecuPdf(List<int> operationIds) =>
      _appel(() => _datasource.getRecuPdf(operationIds));

  @override
  Future<Either<Failure, RecuEcritures>> getRecu(List<int> operationIds) =>
      _appel(() async =>
          recuEcrituresFromJson(await _datasource.getRecu(operationIds)));

  Future<Either<Failure, T>> _appel<T>(Future<T> Function() appel) async {
    try {
      return Right(await appel());
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
