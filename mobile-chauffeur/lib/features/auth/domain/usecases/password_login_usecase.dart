import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/auth_tokens.dart';
import '../repositories/auth_repository.dart';

class PasswordLoginUseCase {
  final AuthRepository _repository;
  const PasswordLoginUseCase(this._repository);

  Future<Either<Failure, AuthTokens>> call(
          String identifiant, String motDePasse) =>
      _repository.passwordLogin(identifiant, motDePasse);
}
