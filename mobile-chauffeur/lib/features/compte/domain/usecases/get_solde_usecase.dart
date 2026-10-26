import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/solde.dart';
import '../repositories/compte_repository.dart';

class GetSoldeUseCase {
  final CompteRepository _repository;
  const GetSoldeUseCase(this._repository);

  Future<Either<Failure, Solde>> call() => _repository.getSolde();

  /// Dernier solde reçu, à afficher en attendant [call].
  Future<Solde?> enCache() => _repository.getSoldeEnCache();
}
