import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../operation_financiere/domain/enums/mode_paiement.dart';
import '../../domain/entities/encaissement_versement.dart';
import '../../domain/entities/versement.dart';
import '../../domain/repositories/versement_repository.dart';
import '../datasources/versement_remote_datasource.dart';

class VersementRepositoryImpl implements VersementRepository {
  final VersementRemoteDatasource _datasource;
  const VersementRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, VersementEnregistre>> encaisser({
    PartVersement? recette,
    PartVersement? cotisation,
    required ModePaiement mode,
    required DateTime date,
    String? reference,
    String? commentaire,
  }) =>
      _appel(() => _datasource.encaisser(
            recette: recette,
            cotisation: cotisation,
            modeEncaissement: mode.name,
            dateEncaissement: date,
            reference: reference,
            commentaire: commentaire,
          ));

  @override
  Future<Either<Failure, ResultatVersementLot>> encaisserLot({
    required List<ElementVersementLot> versements,
    required ModePaiement mode,
    required DateTime date,
    String? reference,
    String? commentaire,
  }) =>
      _appel(() => _datasource.encaisserLot(
            versements: versements,
            modeEncaissement: mode.name,
            dateEncaissement: date,
            reference: reference,
            commentaire: commentaire,
          ));

  @override
  Future<Either<Failure, Versement>> getVersement(String versementId) =>
      _appel(() => _datasource.getVersement(versementId));

  Future<Either<Failure, T>> _appel<T>(Future<T> Function() appel) async {
    try {
      return Right(await appel());
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Failure _mapApiException(ApiException e) {
    return switch (e.statusCode) {
      404 => NotFoundFailure(e.message),
      409 => ConflictFailure(e.message),
      422 => ValidationFailure(e.message),
      401 || 403 => AuthFailure(e.message),
      _ when e.statusCode >= 400 && e.statusCode < 500 => ValidationFailure(e.message),
      _ => ServerFailure(e.message, statusCode: e.statusCode),
    };
  }
}
