import '../../domain/entities/ligne_cotisation.dart';

sealed class LigneCotisationState { const LigneCotisationState(); }
class LigneCotisationInitial extends LigneCotisationState { const LigneCotisationInitial(); }
class LigneCotisationLoading extends LigneCotisationState { const LigneCotisationLoading(); }
class LigneCotisationLoaded extends LigneCotisationState {
  final List<LigneCotisation> lignes;
  const LigneCotisationLoaded(this.lignes);
}
class LigneCotisationActionSuccess extends LigneCotisationState {
  final List<LigneCotisation> lignes;
  const LigneCotisationActionSuccess(this.lignes);
}
class LigneCotisationError extends LigneCotisationState {
  final String message;
  const LigneCotisationError(this.message);
}
