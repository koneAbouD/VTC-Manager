/// Entité domaine représentant les tokens JWT retournés après authentification.
/// Pur Dart — aucune dépendance externe.
class Token {
  final String accessToken;
  final String? refreshToken;
  final int expiresIn;
  final int? refreshExpiresIn;

  const Token({
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
    this.refreshExpiresIn,
  });
}
