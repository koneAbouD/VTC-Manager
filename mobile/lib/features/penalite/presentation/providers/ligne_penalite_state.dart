import '../../domain/entities/ligne_penalite.dart';

sealed class LignePenaliteState { const LignePenaliteState(); }

class LignePenaliteInitial extends LignePenaliteState {
  const LignePenaliteInitial();
}

class LignePenaliteLoading extends LignePenaliteState {
  const LignePenaliteLoading();
}

class LignePenaliteLoaded extends LignePenaliteState {
  final List<LignePenalite> lignes;
  const LignePenaliteLoaded(this.lignes);
}

class LignePenaliteActionSuccess extends LignePenaliteState {
  final List<LignePenalite> lignes;
  const LignePenaliteActionSuccess(this.lignes);
}

class LignePenaliteError extends LignePenaliteState {
  final String message;
  const LignePenaliteError(this.message);
}
