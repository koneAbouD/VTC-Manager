import 'package:fpdart/fpdart.dart';

import 'exception.dart';
import 'failure.dart';

/// Convertit une exception de la couche réseau en [Failure] métier.
Failure mapException(Object e) {
  if (e is ApiException) {
    return switch (e.statusCode) {
      404 => NotFoundFailure(e.message),
      409 => ConflictFailure(e.message),
      422 => ValidationFailure(e.message),
      401 || 403 => AuthFailure(e.message),
      _ when e.statusCode >= 400 && e.statusCode < 500 =>
        ValidationFailure(e.message),
      _ => ServerFailure(e.message, statusCode: e.statusCode),
    };
  }
  if (e is NetworkException) return NetworkFailure(e.message);
  return UnknownFailure(e.toString());
}

/// Exécute [action] et enveloppe le résultat dans un `Either<Failure, T>`,
/// centralisant la conversion exception → Failure des repositories.
Future<Either<Failure, T>> guard<T>(Future<T> Function() action) async {
  try {
    return Right(await action());
  } catch (e) {
    return Left(mapException(e));
  }
}
