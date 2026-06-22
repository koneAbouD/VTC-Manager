/// Sealed class représentant toutes les erreurs métier de l'application.
/// Utilisée avec Either<Failure, T> pour éviter les exceptions non gérées.
sealed class Failure {
  final String message;
  const Failure(this.message);
}

/// Erreur réseau (timeout, pas de connexion)
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Pas de connexion réseau.']);
}

/// Erreur serveur (4xx, 5xx)
class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

/// Ressource introuvable (404)
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Ressource introuvable.']);
}

/// Erreur d'authentification (401 / credentials invalides)
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentification échouée.']);
}

/// Erreur de validation / données invalides (400)
class ValidationFailure extends Failure {
  final List<String> errors;
  const ValidationFailure(super.message, {this.errors = const []});
}

/// Conflit de données — ressource déjà existante (409)
class ConflictFailure extends Failure {
  const ConflictFailure([super.message = 'Cette valeur est déjà utilisée.']);
}

/// Conflit d'affectation — chauffeur déjà assigné à un autre véhicule (409)
class ChauffeurConflictFailure extends Failure {
  final int chauffeurId;
  final String chauffeurNom;
  final int vehiculeActuelId;
  final String vehiculeActuelImmatriculation;

  const ChauffeurConflictFailure({
    required String message,
    required this.chauffeurId,
    required this.chauffeurNom,
    required this.vehiculeActuelId,
    required this.vehiculeActuelImmatriculation,
  }) : super(message);
}

/// Erreur inconnue / non catégorisée
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Une erreur inattendue s\'est produite.']);
}
