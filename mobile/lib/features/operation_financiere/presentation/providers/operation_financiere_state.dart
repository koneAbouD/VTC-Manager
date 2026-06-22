import '../../domain/entities/operation_financiere.dart';

sealed class OperationFinanciereState {
  const OperationFinanciereState();
}

class OperationFinanciereInitial extends OperationFinanciereState {
  const OperationFinanciereInitial();
}

class OperationFinanciereLoading extends OperationFinanciereState {
  const OperationFinanciereLoading();
}

class OperationFinanciereLoaded extends OperationFinanciereState {
  final List<OperationFinanciere> operations;
  const OperationFinanciereLoaded(this.operations);
}

class OperationFinanciereActionSuccess extends OperationFinanciereState {
  final List<OperationFinanciere> operations;
  final String message;
  const OperationFinanciereActionSuccess(this.operations, this.message);
}

class OperationFinanciereError extends OperationFinanciereState {
  final String message;
  const OperationFinanciereError(this.message);
}
