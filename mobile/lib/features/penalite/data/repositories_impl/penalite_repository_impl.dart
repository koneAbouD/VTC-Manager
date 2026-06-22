import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/encaissement_penalite.dart';
import '../../domain/entities/ligne_penalite.dart';
import '../../domain/entities/ligne_penalite_filtres.dart';
import '../../domain/repositories/penalite_repository.dart';
import '../datasources/penalite_remote_datasource.dart';
import '../models/encaissement_penalite_model.dart';

class PenaliteRepositoryImpl implements PenaliteRepository {
  final PenaliteRemoteDatasource _datasource;
  const PenaliteRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<LignePenalite>>> getLignes(
      LignePenaliteFiltres filtres) async {
    try {
      final result = await _datasource.getLignes(
        vehiculeId: filtres.vehiculeId,
        chauffeurId: filtres.chauffeurId,
        typeSanction: _typeSanctionToString(filtres.typeSanction),
        statut: _statutToString(filtres.statut),
        dateDebut: filtres.dateDebut?.toIso8601String().substring(0, 10),
        dateFin: filtres.dateFin?.toIso8601String().substring(0, 10),
      );
      return Right(result);
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LignePenalite>> getLigneById(int id) async {
    try {
      return Right(await _datasource.getLigneById(id));
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LignePenalite>> createLigne(
      Map<String, dynamic> data) async {
    try {
      return Right(await _datasource.createLigne(data));
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LignePenalite>> signalerRetard(
      Map<String, dynamic> data) async {
    try {
      return Right(await _datasource.signalerRetard(data));
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, EncaissementPenalite>> createEncaissement(
      int ligneId, Map<String, dynamic> data) async {
    try {
      final model = EncaissementPenaliteModel(
        lignePenaliteId: ligneId,
        montant: (data['montant'] as num).toDouble(),
        modeEncaissement: data['modeEncaissement'] as String,
        dateEncaissement: data['dateEncaissement'] as DateTime,
        reference: data['reference'] as String?,
        commentaire: data['commentaire'] as String?,
      );
      return Right(await _datasource.createEncaissement(ligneId, model));
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EncaissementPenalite>>> getEncaissements(
      int ligneId) async {
    try {
      return Right(await _datasource.getEncaissements(ligneId));
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LignePenalite>> executer(int id) async =>
      _action(() => _datasource.executer(id));

  @override
  Future<Either<Failure, LignePenalite>> notifier(int id) async =>
      _action(() => _datasource.notifier(id));

  @override
  Future<Either<Failure, LignePenalite>> demarrer(int id) async =>
      _action(() => _datasource.demarrer(id));

  @override
  Future<Either<Failure, LignePenalite>> lever(int id) async =>
      _action(() => _datasource.lever(id));

  @override
  Future<Either<Failure, LignePenalite>> annuler(int id) async =>
      _action(() => _datasource.annuler(id));

  @override
  Future<Either<Failure, List<LignePenalite>>> generer({DateTime? date}) async {
    try {
      final result = await _datasource.generer(
          date: date?.toIso8601String().substring(0, 10));
      return Right(result);
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<Either<Failure, LignePenalite>> _action(
      Future<LignePenalite> Function() fn) async {
    try {
      return Right(await fn());
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  String? _typeSanctionToString(TypeSanctionLigne? t) => switch (t) {
        TypeSanctionLigne.buzzer         => 'BUZZER',
        TypeSanctionLigne.amende         => 'AMENDE',
        TypeSanctionLigne.avertissement  => 'AVERTISSEMENT',
        TypeSanctionLigne.immobilisation => 'IMMOBILISATION',
        null                             => null,
      };

  String? _statutToString(StatutLignePenalite? s) => switch (s) {
        StatutLignePenalite.enAttente              => 'EN_ATTENTE',
        StatutLignePenalite.partiellementEncaissee => 'PARTIELLEMENT_ENCAISSEE',
        StatutLignePenalite.encaissee              => 'ENCAISSEE',
        StatutLignePenalite.executee               => 'EXECUTEE',
        StatutLignePenalite.notifiee               => 'NOTIFIEE',
        StatutLignePenalite.enCours                => 'EN_COURS',
        StatutLignePenalite.levee                  => 'LEVEE',
        StatutLignePenalite.annulee                => 'ANNULEE',
        null                                       => null,
      };

  Failure _map(ApiException e) => switch (e.statusCode) {
        404        => NotFoundFailure(e.message),
        409        => ConflictFailure(e.message),
        422        => ValidationFailure(e.message),
        401 || 403 => AuthFailure(e.message),
        _          => ServerFailure(e.message, statusCode: e.statusCode),
      };
}
