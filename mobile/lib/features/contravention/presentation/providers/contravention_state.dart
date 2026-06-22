import '../../domain/entities/contravention.dart';

sealed class ContraventionState {
  const ContraventionState();
}

class ContraventionInitial extends ContraventionState {
  const ContraventionInitial();
}

class ContraventionLoading extends ContraventionState {
  const ContraventionLoading();
}

class ContraventionLoaded extends ContraventionState {
  final List<Contravention> contraventions;
  const ContraventionLoaded(this.contraventions);
}

class ContraventionActionSuccess extends ContraventionState {
  final List<Contravention> contraventions;
  final String message;
  const ContraventionActionSuccess(this.contraventions, this.message);
}

class ContraventionError extends ContraventionState {
  final String message;
  const ContraventionError(this.message);
}
