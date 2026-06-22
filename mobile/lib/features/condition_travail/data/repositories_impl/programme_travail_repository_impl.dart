import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/programme_travail.dart';
import '../../domain/repositories/programme_travail_repository.dart';
import '../datasources/programme_travail_remote_datasource.dart';
import '../models/programme_travail_model.dart';

class ProgrammeTravailRepositoryImpl implements ProgrammeTravailRepository {
  final ProgrammeTravailRemoteDatasource _datasource;

  const ProgrammeTravailRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, ProgrammeTravail>> getProgramme(int vehiculeId) async {
    try {
      return Right(await _datasource.getProgramme(vehiculeId));
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProgrammeTravail>> createProgramme(
    int vehiculeId,
    ProgrammeTravail programme, {
    bool force = false,
  }) async {
    try {
      final model = ProgrammeTravailModel.fromEntity(programme);
      return Right(
          await _datasource.createProgramme(vehiculeId, model, force: force));
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProgrammeTravail>> updateProgramme(
    int vehiculeId,
    ProgrammeTravail programme, {
    bool force = false,
  }) async {
    try {
      final model = ProgrammeTravailModel.fromEntity(programme);
      return Right(
          await _datasource.updateProgramme(vehiculeId, model, force: force));
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProgrammeTravail>> invertProgramme(
    int vehiculeId,
  ) async {
    try {
      return Right(await _datasource.invertProgramme(vehiculeId));
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Failure _mapApiException(ApiException e) {
    if (e.statusCode == 409 &&
        e.body?['error'] == 'CHAUFFEUR_ALREADY_ASSIGNED') {
      return _parseChauffeurConflict(e);
    }
    if (e.statusCode == 404) return NotFoundFailure(e.message);
    if (e.statusCode == 401 || e.statusCode == 403) {
      return AuthFailure(e.message);
    }
    if (e.statusCode >= 400 && e.statusCode < 500) {
      return ValidationFailure(e.message);
    }
    return ServerFailure(e.message, statusCode: e.statusCode);
  }

  ChauffeurConflictFailure _parseChauffeurConflict(ApiException e) {
    final details = (e.body?['details'] as List?)?.cast<String>() ?? [];
    int chauffeurId = 0;
    String chauffeurNom = '';
    int vehiculeActuelId = 0;
    String vehiculeActuelImmatriculation = '';

    for (final d in details) {
      if (d.startsWith('chauffeurId:')) {
        chauffeurId = int.tryParse(d.substring('chauffeurId:'.length)) ?? 0;
      } else if (d.startsWith('chauffeurNom:')) {
        chauffeurNom = d.substring('chauffeurNom:'.length);
      } else if (d.startsWith('vehiculeActuelId:')) {
        vehiculeActuelId =
            int.tryParse(d.substring('vehiculeActuelId:'.length)) ?? 0;
      } else if (d.startsWith('vehiculeActuelImmatriculation:')) {
        vehiculeActuelImmatriculation =
            d.substring('vehiculeActuelImmatriculation:'.length);
      }
    }

    return ChauffeurConflictFailure(
      message: e.message,
      chauffeurId: chauffeurId,
      chauffeurNom: chauffeurNom,
      vehiculeActuelId: vehiculeActuelId,
      vehiculeActuelImmatriculation: vehiculeActuelImmatriculation,
    );
  }
}
