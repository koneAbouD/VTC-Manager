import '../../domain/entities/depense.dart';

sealed class DepenseState {
  const DepenseState();
}

class DepenseInitial extends DepenseState {
  const DepenseInitial();
}

class DepenseLoading extends DepenseState {
  const DepenseLoading();
}

class DepenseLoaded extends DepenseState {
  final List<Depense> depenses;
  const DepenseLoaded(this.depenses);
}

class DepenseActionSuccess extends DepenseState {
  final List<Depense> depenses;
  final String message;
  const DepenseActionSuccess(this.depenses, this.message);
}

class DepenseError extends DepenseState {
  final String message;
  const DepenseError(this.message);
}
