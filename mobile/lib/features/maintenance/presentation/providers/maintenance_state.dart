import '../../domain/entities/maintenance.dart';

sealed class MaintenanceState {
  const MaintenanceState();
}

class MaintenanceInitial extends MaintenanceState {
  const MaintenanceInitial();
}

class MaintenanceLoading extends MaintenanceState {
  const MaintenanceLoading();
}

class MaintenanceLoaded extends MaintenanceState {
  final List<Maintenance> maintenances;
  const MaintenanceLoaded(this.maintenances);
}

class MaintenanceActionSuccess extends MaintenanceState {
  final List<Maintenance> maintenances;
  final String message;
  const MaintenanceActionSuccess(this.maintenances, this.message);
}

class MaintenanceError extends MaintenanceState {
  final String message;
  const MaintenanceError(this.message);
}
