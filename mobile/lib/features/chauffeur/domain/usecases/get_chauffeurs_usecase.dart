import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/chauffeur.dart';
import '../repositories/chauffeur_repository.dart';

class GetChauffeursUseCase {
  final ChauffeurRepository _repository;
  const GetChauffeursUseCase(this._repository);

  Future<Either<Failure, List<Chauffeur>>> call() =>
      _repository.getChauffeurs();

  /// Dernière liste reçue, à afficher en attendant [call].
  Future<List<Chauffeur>?> enCache() => _repository.getChauffeursEnCache();
}
