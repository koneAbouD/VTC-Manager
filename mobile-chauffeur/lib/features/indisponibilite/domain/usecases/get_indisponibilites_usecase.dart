import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/indisponibilite.dart';
import '../repositories/indisponibilite_repository.dart';

class GetIndisponibilitesUseCase {
  final IndisponibiliteRepository _repository;
  const GetIndisponibilitesUseCase(this._repository);

  Future<Either<Failure, List<Indisponibilite>>> call() =>
      _repository.getIndisponibilites();
}
