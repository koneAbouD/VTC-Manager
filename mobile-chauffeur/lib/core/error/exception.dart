/// Exception lancée par la couche réseau (datasource).
/// Toujours convertie en [Failure] dans le repository.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;
  const ApiException(this.statusCode, this.message, {this.body});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Exception réseau bas niveau (timeout, pas de connexion).
class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Pas de connexion réseau.']);

  @override
  String toString() => message;
}

/// Extrait un message lisible à présenter à l'utilisateur à partir de
/// n'importe quelle erreur capturée.
///
/// Priorité au message renvoyé par le backend ([ApiException.message], ex.
/// « Le document est trop volumineux. La taille maximale autorisée est de
/// 1MB… »), puis au message réseau, et enfin à [fallback] en dernier recours.
String messageFromError(
  Object error, {
  String fallback = "Une erreur est survenue, veuillez réessayer.",
}) {
  if (error is ApiException) {
    return error.message.trim().isNotEmpty ? error.message.trim() : fallback;
  }
  if (error is NetworkException) {
    return error.message.trim().isNotEmpty ? error.message.trim() : fallback;
  }
  // Les providers de présentation lèvent le message d'une Failure (String).
  if (error is String) {
    return error.trim().isNotEmpty ? error.trim() : fallback;
  }
  return fallback;
}
