import '../../domain/entities/recette.dart';

sealed class RecetteState {
  const RecetteState();
}

class RecetteInitial extends RecetteState {
  const RecetteInitial();
}

class RecetteLoading extends RecetteState {
  const RecetteLoading();
}

class RecetteLoaded extends RecetteState {
  final List<Recette> recettes;
  const RecetteLoaded(this.recettes);
}

class RecetteActionSuccess extends RecetteState {
  final List<Recette> recettes;
  final String message;
  const RecetteActionSuccess(this.recettes, this.message);
}

class RecetteError extends RecetteState {
  final String message;
  const RecetteError(this.message);
}
