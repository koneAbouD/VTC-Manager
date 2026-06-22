import '../../domain/entities/vehicule.dart';

sealed class VehiculeState {
  const VehiculeState();
}

class VehiculeInitial extends VehiculeState {
  const VehiculeInitial();
}

class VehiculeLoading extends VehiculeState {
  const VehiculeLoading();
}

class VehiculeLoaded extends VehiculeState {
  final List<Vehicule> vehicules;
  const VehiculeLoaded(this.vehicules);
}

class VehiculeActionSuccess extends VehiculeState {
  final List<Vehicule> vehicules;
  final String message;
  const VehiculeActionSuccess(this.vehicules, this.message);
}

class VehiculeError extends VehiculeState {
  final String message;
  const VehiculeError(this.message);
}
