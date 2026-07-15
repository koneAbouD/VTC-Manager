import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _datasource;
  const AuthRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, Unit>> requestOtp(String telephone) =>
      guard(() async {
        await _datasource.requestOtp(telephone);
        return unit;
      });

  @override
  Future<Either<Failure, AuthTokens>> verifyOtp(String telephone, String code) =>
      guard(() => _datasource.verifyOtp(telephone, code));

  @override
  Future<Either<Failure, AuthTokens>> passwordLogin(
          String identifiant, String motDePasse) =>
      guard(() => _datasource.passwordLogin(identifiant, motDePasse));

  @override
  Future<Either<Failure, Unit>> setPassword(String motDePasse) => guard(() async {
        await _datasource.setPassword(motDePasse);
        return unit;
      });
}
