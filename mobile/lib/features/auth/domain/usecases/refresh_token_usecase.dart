import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/token.dart';
import '../repositories/auth_repository.dart';

class RefreshTokenUseCase {
  final AuthRepository _repository;
  const RefreshTokenUseCase(this._repository);

  Future<Either<Failure, Token>> call() => _repository.refreshToken();
}
