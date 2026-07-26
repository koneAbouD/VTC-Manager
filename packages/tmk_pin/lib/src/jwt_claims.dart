import 'dart:convert';

/// Lecture des revendications d'un JWT, sans vérification de signature.
///
/// Suffisant et sans risque ici : le jeton vient d'être reçu du backend par
/// HTTPS et n'est lu que pour de l'affichage. Toute décision de sécurité reste
/// prise côté serveur, qui, lui, valide la signature.
class JwtClaims {
  final Map<String, dynamic> values;

  const JwtClaims(this.values);

  /// Retourne des revendications vides si le jeton est illisible — un écran
  /// d'accueil ne doit jamais faire échouer une connexion.
  factory JwtClaims.parse(String? token) {
    if (token == null) return const JwtClaims({});
    final parts = token.split('.');
    if (parts.length < 2) return const JwtClaims({});
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      return JwtClaims(decoded is Map<String, dynamic> ? decoded : const {});
    } catch (_) {
      return const JwtClaims({});
    }
  }

  String? string(String claim) {
    final value = values[claim];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Prénom (`given_name`) — renseigné pour les chauffeurs par le
  /// provisionnement Keycloak, et pour les gestionnaires à l'inscription.
  String? get givenName => string('given_name');

  /// Identifiant de connexion. Côté application chauffeur, c'est le **numéro
  /// de téléphone** canonique : à ne jamais afficher tel quel (voir
  /// [DisplayName.resolve]).
  String? get preferredUsername => string('preferred_username');
}

/// Choix du nom à afficher sur l'écran de verrouillage.
class DisplayName {
  const DisplayName._();

  /// Un identifiant qui n'est qu'un numéro de téléphone ne doit pas s'afficher :
  /// « Heureux de vous revoir +2250708… » n'a aucun sens, et exposer le numéro
  /// sur un écran verrouillé est gratuitement indiscret.
  static final _phoneLike = RegExp(r'^\+?[\d\s.\-()]{6,}$');

  static bool looksLikePhoneNumber(String value) =>
      _phoneLike.hasMatch(value.trim());

  /// Ordre de préférence :
  ///  1. [profileFirstName] — le prénom métier (`/me/profil`), source de vérité
  ///     quand l'application en dispose ;
  ///  2. `given_name` du jeton, disponible dès la connexion et hors ligne ;
  ///  3. l'identifiant de connexion, **sauf** s'il ressemble à un téléphone ;
  ///  4. `null` : l'écran salue alors sans nommer personne.
  static String? resolve({
    String? profileFirstName,
    String? accessToken,
    JwtClaims? claims,
  }) {
    final profile = profileFirstName?.trim();
    if (profile != null && profile.isNotEmpty) return profile;

    final jwt = claims ?? JwtClaims.parse(accessToken);
    final given = jwt.givenName;
    if (given != null) return given;

    final username = jwt.preferredUsername;
    if (username != null && !looksLikePhoneNumber(username)) return username;

    return null;
  }
}
