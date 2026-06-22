import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/token.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;
  const LoginUseCase(this._repository);

  Future<Either<Failure, Token>> call(String username, String password) =>
      _repository.login(username, password);
}
