import '../../domain/entities/ligne_recette.dart';

sealed class LigneRecetteState {
  const LigneRecetteState();
}

class LigneRecetteInitial extends LigneRecetteState {
  const LigneRecetteInitial();
}

class LigneRecetteLoading extends LigneRecetteState {
  const LigneRecetteLoading();
}

class LigneRecetteLoaded extends LigneRecetteState {
  final List<LigneRecette> lignes;
  const LigneRecetteLoaded(this.lignes);
}

class LigneRecetteActionSuccess extends LigneRecetteState {
  final List<LigneRecette> lignes;
  final String message;
  const LigneRecetteActionSuccess(this.lignes, this.message);
}

class LigneRecetteError extends LigneRecetteState {
  final String message;
  const LigneRecetteError(this.message);
}
