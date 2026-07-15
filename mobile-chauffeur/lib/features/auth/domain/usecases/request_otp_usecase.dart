import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/auth_repository.dart';

class RequestOtpUseCase {
  final AuthRepository _repository;
  const RequestOtpUseCase(this._repository);

  Future<Either<Failure, Unit>> call(String telephone) =>
      _repository.requestOtp(telephone);
}
