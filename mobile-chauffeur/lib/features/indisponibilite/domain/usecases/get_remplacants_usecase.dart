import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/remplacant.dart';
import '../repositories/indisponibilite_repository.dart';

class GetRemplacantsUseCase {
  final IndisponibiliteRepository _repository;
  const GetRemplacantsUseCase(this._repository);

  Future<Either<Failure, List<Remplacant>>> call() =>
      _repository.getRemplacants();
}
