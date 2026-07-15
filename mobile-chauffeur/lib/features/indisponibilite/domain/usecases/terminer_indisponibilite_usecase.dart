import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/indisponibilite.dart';
import '../repositories/indisponibilite_repository.dart';

class TerminerIndisponibiliteUseCase {
  final IndisponibiliteRepository _repository;
  const TerminerIndisponibiliteUseCase(this._repository);

  Future<Either<Failure, Indisponibilite>> call(int id) =>
      _repository.terminer(id);
}
