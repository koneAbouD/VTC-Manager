import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/encaissement_cotisation.dart';
import '../../domain/entities/ligne_cotisation.dart';
import '../../domain/entities/ligne_cotisation_filtres.dart';
import '../../domain/repositories/ligne_cotisation_repository.dart';
import '../datasources/ligne_cotisation_remote_datasource.dart';
import '../models/encaissement_cotisation_model.dart';

class LigneCotisationRepositoryImpl implements LigneCotisationRepository {
  final LigneCotisationRemoteDatasource _datasource;
  const LigneCotisationRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<LigneCotisation>>> getLignes(LigneCotisationFiltres f) async {
    try {
      return Right(await _datasource.getLignes(
        vehiculeId: f.vehiculeId,
        chauffeurId: f.chauffeurId,
        statut: _statutStr(f.statut),
        dateDebut: f.dateDebut?.toIso8601String().substring(0, 10),
        dateFin: f.dateFin?.toIso8601String().substring(0, 10),
      ));
    } on ApiException catch (e) { return Left(_map(e)); }
    on NetworkException catch (e) { return Left(NetworkFailure(e.message)); }
    catch (e) { return Left(UnknownFailure(e.toString())); }
  }

  @override
  Future<Either<Failure, LigneCotisation>> getLigneById(int id) async {
    try { return Right(await _datasource.getLigneById(id)); }
    on ApiException catch (e) { return Left(_map(e)); }
    on NetworkException catch (e) { return Left(NetworkFailure(e.message)); }
    catch (e) { return Left(UnknownFailure(e.toString())); }
  }

  @override
  Future<Either<Failure, EncaissementCotisation>> createEncaissement(
      int ligneId, EncaissementCotisation enc) async {
    try {
      final model = EncaissementCotisationModel(
        ligneCotisationId: enc.ligneCotisationId,
        montant: enc.montant,
        modeEncaissement: enc.modeEncaissement,
        dateEncaissement: enc.dateEncaissement,
        reference: enc.reference,
        commentaire: enc.commentaire,
      );
      return Right(await _datasource.createEncaissement(ligneId, model));
    } on ApiException catch (e) { return Left(_map(e)); }
    on NetworkException catch (e) { return Left(NetworkFailure(e.message)); }
    catch (e) { return Left(UnknownFailure(e.toString())); }
  }

  @override
  Future<Either<Failure, LigneCotisation>> annuler(int id) async {
    try { return Right(await _datasource.annuler(id)); }
    on ApiException catch (e) { return Left(_map(e)); }
    on NetworkException catch (e) { return Left(NetworkFailure(e.message)); }
    catch (e) { return Left(UnknownFailure(e.toString())); }
  }

  @override
  Future<Either<Failure, List<LigneCotisation>>> generer({DateTime? date}) async {
    try {
      return Right(await _datasource.generer(date: date?.toIso8601String().substring(0, 10)));
    } on ApiException catch (e) { return Left(_map(e)); }
    on NetworkException catch (e) { return Left(NetworkFailure(e.message)); }
    catch (e) { return Left(UnknownFailure(e.toString())); }
  }

  String? _statutStr(StatutLigneCotisation? s) => switch (s) {
        StatutLigneCotisation.enAttente             => 'EN_ATTENTE',
        StatutLigneCotisation.partiellementEncaisse => 'PARTIELLEMENT_ENCAISSE',
        StatutLigneCotisation.encaisse              => 'ENCAISSE',
        StatutLigneCotisation.annulee               => 'ANNULEE',
        null                                        => null,
      };

  Failure _map(ApiException e) => switch (e.statusCode) {
        404        => NotFoundFailure(e.message),
        409        => ConflictFailure(e.message),
        422        => ValidationFailure(e.message),
        401 || 403 => AuthFailure(e.message),
        _          => ServerFailure(e.message, statusCode: e.statusCode),
      };
}
