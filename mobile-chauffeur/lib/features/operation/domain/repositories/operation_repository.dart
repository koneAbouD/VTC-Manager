import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/operation_financiere.dart';

abstract interface class OperationRepository {
  Future<Either<Failure, List<OperationFinanciere>>> getOperations();

  /// Dernières opérations reçues, sans appel au serveur ; `null` si aucune.
  Future<List<OperationFinanciere>?> getOperationsEnCache();
}
