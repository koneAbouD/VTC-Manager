import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ligne_cotisation.dart';
import '../repositories/cotisation_repository.dart';

class GetCotisationsUseCase {
  final CotisationRepository _repository;
  const GetCotisationsUseCase(this._repository);

  Future<Either<Failure, List<LigneCotisation>>> call() =>
      _repository.getCotisations();
}
