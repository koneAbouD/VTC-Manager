import '../../domain/entities/chauffeur.dart';

sealed class ChauffeurState {
  const ChauffeurState();
}

class ChauffeurInitial extends ChauffeurState {
  const ChauffeurInitial();
}

class ChauffeurLoading extends ChauffeurState {
  const ChauffeurLoading();
}

class ChauffeurLoaded extends ChauffeurState {
  final List<Chauffeur> chauffeurs;
  const ChauffeurLoaded(this.chauffeurs);
}

class ChauffeurActionSuccess extends ChauffeurState {
  final List<Chauffeur> chauffeurs;
  final String message;
  const ChauffeurActionSuccess(this.chauffeurs, this.message);
}

class ChauffeurError extends ChauffeurState {
  final String message;
  const ChauffeurError(this.message);
}
