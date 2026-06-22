import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/chauffeur.dart';
import '../../domain/repositories/chauffeur_repository.dart';
import '../datasources/chauffeur_remote_datasource.dart';
import '../models/chauffeur_request_model.dart';

class ChauffeurRepositoryImpl implements ChauffeurRepository {
  final ChauffeurRemoteDatasource _datasource;
  const ChauffeurRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<Chauffeur>>> getChauffeurs() async {
    try {
      final result = await _datasource.getChauffeurs();
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
  Future<Either<Failure, Chauffeur>> getChauffeurById(int id) async {
    try {
      final result = await _datasource.getChauffeurById(id);
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
  Future<Either<Failure, Chauffeur>> createChauffeur(
    Chauffeur chauffeur, {
    Uint8List? permisBytes,
    String permisFilename = 'permis.jpg',
    Uint8List? photoBytes,
    String photoFilename = 'photo.jpg',
    String? numeroPermis,
    List<String>? typesPermis,
    DateTime? dateEmissionPermis,
    DateTime? dateExpirationPermis,
  }) async {
    try {
      final request = ChauffeurRequestModel.fromChauffeur(
        chauffeur,
        numeroPermis: numeroPermis,
        typesPermisStr: typesPermis,
        dateEmissionPermis: dateEmissionPermis,
        dateExpirationPermis: dateExpirationPermis,
      );
      final result = await _datasource.createChauffeur(
        request,
        permisBytes: permisBytes,
        permisFilename: permisFilename,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
      return Right(result);
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ArgumentError catch (e) {
      return Left(ValidationFailure(e.message.toString()));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Chauffeur>> updateChauffeur(
    int id,
    Chauffeur chauffeur, {
    Uint8List? permisBytes,
    String permisFilename = 'permis.jpg',
    Uint8List? photoBytes,
    String photoFilename = 'photo.jpg',
    bool deletePhoto = false,
  }) async {
    try {
      final request = ChauffeurRequestModel.fromChauffeur(chauffeur)
          .copyWith(deletePhoto: deletePhoto);
      final result = await _datasource.updateChauffeur(
        id,
        request,
        permisBytes: permisBytes,
        permisFilename: permisFilename,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
      return Right(result);
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ArgumentError catch (e) {
      return Left(ValidationFailure(e.message.toString()));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteChauffeur(int id) async {
    try {
      await _datasource.deleteChauffeur(id);
      return const Right(null);
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Failure _mapApiException(ApiException e) {
    if (e.statusCode == 404) return NotFoundFailure(e.message);
    if (e.statusCode == 401 || e.statusCode == 403) {
      return AuthFailure(e.message);
    }
    if (e.statusCode >= 400 && e.statusCode < 500) {
      return ValidationFailure(e.message);
    }
    return ServerFailure(e.message, statusCode: e.statusCode);
  }
}
