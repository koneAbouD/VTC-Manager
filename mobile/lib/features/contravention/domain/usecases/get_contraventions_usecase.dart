import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/contravention.dart';
import '../repositories/contravention_repository.dart';

class GetContraventionsUseCase {
  final ContraventionRepository _repository;
  const GetContraventionsUseCase(this._repository);

  Future<Either<Failure, List<Contravention>>> call() =>
      _repository.getContraventions();
}
