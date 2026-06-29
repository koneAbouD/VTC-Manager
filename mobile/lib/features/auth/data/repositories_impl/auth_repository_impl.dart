import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/token.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Adaptateur : implémente [AuthRepository] en s'appuyant sur
/// [AuthRemoteDatasource] et [SecureStorage].
/// Traduit toutes les exceptions en [Failure].
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remote;
  final SecureStorage _storage;

  const AuthRepositoryImpl(this._remote, this._storage);

  @override
  Future<Either<Failure, Token>> login(
      String username, String password) async {
    try {
      final model = await _remote.login(username, password);
      await _storage.saveTokens(
        accessToken: model.accessToken,
        refreshToken: model.refreshToken,
        expiresInSeconds: model.expiresIn,
      );
      return Right(model);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 400) {
        return const Left(AuthFailure('Identifiants invalides.'));
      }
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      await _remote.register(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      return const Right(null);
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        return const Left(
            ValidationFailure('Nom d\'utilisateur ou email déjà utilisé.'));
      }
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Token>> refreshToken() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh == null) {
      return const Left(AuthFailure('Session expirée. Reconnectez-vous.'));
    }
    try {
      final model = await _remote.refreshToken(refresh);
      await _storage.saveTokens(
        accessToken: model.accessToken,
        refreshToken: model.refreshToken ?? refresh,
        expiresInSeconds: model.expiresIn,
      );
      return Right(model);
    } on ApiException catch (e) {
      await _storage.clearTokens();
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh != null) {
      try {
        await _remote.logout(refresh);
      } catch (_) {
        // On nettoie localement même si le backend est injoignable
      }
    }
    await _storage.clearTokens();
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> forgotPassword(String email) async {
    try {
      await _remote.forgotPassword(email);
      return const Right(null);
    } on ApiException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<bool> isAuthenticated() => _storage.hasAccessToken();
}
