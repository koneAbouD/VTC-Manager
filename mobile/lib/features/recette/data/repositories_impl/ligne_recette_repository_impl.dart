import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/encaissement.dart';
import '../../domain/entities/ligne_recette.dart';
import '../../domain/repositories/ligne_recette_repository.dart';
import '../datasources/ligne_recette_remote_datasource.dart';
import '../models/encaissement_model.dart';

class LigneRecetteRepositoryImpl implements LigneRecetteRepository {
  final LigneRecetteRemoteDatasource _datasource;
  const LigneRecetteRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<LigneRecette>>> getLignes({
    int? vehiculeId,
    int? chauffeurId,
    StatutLigneRecette? statut,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    try {
      final result = await _datasource.getLignes(
        vehiculeId: vehiculeId,
        chauffeurId: chauffeurId,
        statut: _statutToString(statut),
        dateDebut: dateDebut?.toIso8601String().substring(0, 10),
        dateFin: dateFin?.toIso8601String().substring(0, 10),
      );
      return Right(result);
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LigneRecette>> getLigneById(int id) async {
    try {
      return Right(await _datasource.getLigneById(id));
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Encaissement>> createEncaissement(
    int ligneId,
    Encaissement encaissement,
  ) async {
    try {
      final model = EncaissementModel(
        ligneRecetteId: encaissement.ligneRecetteId,
        montant: encaissement.montant,
        modeEncaissement: encaissement.modeEncaissement,
        dateEncaissement: encaissement.dateEncaissement,
        reference: encaissement.reference,
        commentaire: encaissement.commentaire,
      );
      return Right(await _datasource.createEncaissement(ligneId, model));
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LigneRecette>> annuler(int id) async {
    try {
      return Right(await _datasource.annuler(id));
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LigneRecette>> confirmerVersement(int id) async {
    try {
      return Right(await _datasource.confirmerVersement(id));
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LigneRecette>>> generer({DateTime? date}) async {
    try {
      final result = await _datasource.generer(
        date: date?.toIso8601String().substring(0, 10),
      );
      return Right(result);
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  String? _statutToString(StatutLigneRecette? statut) => switch (statut) {
        StatutLigneRecette.enAttente => 'EN_ATTENTE',
        StatutLigneRecette.partiellementEncaisse => 'PARTIELLEMENT_ENCAISSE',
        StatutLigneRecette.encaisse => 'ENCAISSE',
        StatutLigneRecette.annulee => 'ANNULEE',
        null => null,
      };

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
