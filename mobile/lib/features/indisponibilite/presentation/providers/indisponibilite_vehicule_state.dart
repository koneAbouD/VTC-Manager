import '../../domain/entities/indisponibilite_vehicule.dart';

sealed class IndisponibiliteVehiculeState {
  const IndisponibiliteVehiculeState();
}

class IndisponibiliteVehiculeInitial extends IndisponibiliteVehiculeState {
  const IndisponibiliteVehiculeInitial();
}

class IndisponibiliteVehiculeLoading extends IndisponibiliteVehiculeState {
  const IndisponibiliteVehiculeLoading();
}

class IndisponibiliteVehiculeLoaded extends IndisponibiliteVehiculeState {
  final List<IndisponibiliteVehicule> indisponibilites;
  const IndisponibiliteVehiculeLoaded(this.indisponibilites);
}

class IndisponibiliteVehiculeError extends IndisponibiliteVehiculeState {
  final String message;
  const IndisponibiliteVehiculeError(this.message);
}
