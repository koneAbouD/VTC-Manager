import '../../domain/entities/indisponibilite.dart';

sealed class IndisponibiliteState {
  const IndisponibiliteState();
}

class IndisponibiliteInitial extends IndisponibiliteState {
  const IndisponibiliteInitial();
}

class IndisponibiliteLoading extends IndisponibiliteState {
  const IndisponibiliteLoading();
}

class IndisponibiliteLoaded extends IndisponibiliteState {
  final List<Indisponibilite> indisponibilites;
  const IndisponibiliteLoaded(this.indisponibilites);
}

class IndisponibiliteError extends IndisponibiliteState {
  final String message;
  const IndisponibiliteError(this.message);
}
