import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/maintenance.dart';
import '../repositories/maintenance_repository.dart';

class CreateMaintenanceUseCase {
  final MaintenanceRepository _repository;
  const CreateMaintenanceUseCase(this._repository);

  /// [aCredit] et [dateEcheance] ne servent qu'à une intervention datée d'avant
  /// aujourd'hui : le serveur la termine à sa création, et il faut lui dire si
  /// elle a été payée sur place ou si elle reste due.
  Future<Either<Failure, Maintenance>> call(
    Maintenance maintenance, {
    bool aCredit = false,
    DateTime? dateEcheance,
  }) =>
      _repository.createMaintenance(maintenance,
          aCredit: aCredit, dateEcheance: dateEcheance);
}
