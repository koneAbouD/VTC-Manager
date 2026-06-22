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
