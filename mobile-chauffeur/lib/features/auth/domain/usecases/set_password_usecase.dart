import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/auth_repository.dart';

class SetPasswordUseCase {
  final AuthRepository _repository;
  const SetPasswordUseCase(this._repository);

  Future<Either<Failure, Unit>> call(String motDePasse) =>
      _repository.setPassword(motDePasse);
}
