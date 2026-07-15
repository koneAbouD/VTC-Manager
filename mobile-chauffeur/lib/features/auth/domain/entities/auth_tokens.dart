/// Jetons d'authentification retournés par le backend.
class AuthTokens {
  final String accessToken;
  final String? refreshToken;
  final int? expiresInSeconds;

  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.expiresInSeconds,
  });
}
