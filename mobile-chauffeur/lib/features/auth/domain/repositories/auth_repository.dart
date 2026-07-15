import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/auth_tokens.dart';

abstract interface class AuthRepository {
  Future<Either<Failure, Unit>> requestOtp(String telephone);
  Future<Either<Failure, AuthTokens>> verifyOtp(String telephone, String code);
  Future<Either<Failure, AuthTokens>> passwordLogin(
      String identifiant, String motDePasse);
  Future<Either<Failure, Unit>> setPassword(String motDePasse);
}
