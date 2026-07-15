import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ligne_penalite.dart';
import '../repositories/penalite_repository.dart';

class GetPenalitesUseCase {
  final PenaliteRepository _repository;
  const GetPenalitesUseCase(this._repository);

  Future<Either<Failure, List<LignePenalite>>> call() =>
      _repository.getPenalites();
}
