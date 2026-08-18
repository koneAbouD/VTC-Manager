import '../../../core/network/api_client.dart';

/// Fiche du compte connecté, telle que Keycloak la détient.
///
/// L'application n'a pas de table utilisateur : ces informations vivent dans
/// le référentiel d'identité, et le backend les sert cadrées sur le jeton.
class ProfilUtilisateur {
  /// Identifiant Keycloak (`sub`).
  final String id;

  /// Identifiant de connexion. Non modifiable : il sert de clé au code d'accès
  /// du téléphone comme aux comptes déjà provisionnés.
  final String identifiant;

  final String prenom;
  final String nom;
  final String email;
  final String telephone;

  /// Rôles realm du compte, tels quels (`ADMIN`, `GESTIONNAIRE`…).
  final List<String> roles;

  const ProfilUtilisateur({
    required this.id,
    required this.identifiant,
    required this.prenom,
    required this.nom,
    required this.email,
    required this.telephone,
    required this.roles,
  });

  factory ProfilUtilisateur.fromJson(Map<String, dynamic> j) =>
      ProfilUtilisateur(
        id: j['id'] as String? ?? '',
        identifiant: j['username'] as String? ?? '',
        prenom: j['firstName'] as String? ?? '',
        nom: j['lastName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        telephone: j['phone'] as String? ?? '',
        roles: (j['roles'] as List<dynamic>? ?? const [])
            .map((r) => '$r')
            .toList(growable: false),
      );

  /// Rôles à montrer : Keycloak en ajoute des techniques (`default-roles-…`,
  /// `offline_access`, `uma_authorization`) qui ne disent rien du métier.
  List<String> get rolesMetier => roles
      .where((r) =>
          !r.startsWith('default-roles') &&
          r != 'offline_access' &&
          r != 'uma_authorization')
      .toList(growable: false);
}

/// Accès REST à la fiche du compte connecté (endpoints /v1/utilisateurs/moi).
class ProfilApi {
  final ApiClient _client;

  const ProfilApi(this._client);

  Future<ProfilUtilisateur> lire() async {
    final res = await _client.get('/v1/utilisateurs/moi');
    return ProfilUtilisateur.fromJson(res as Map<String, dynamic>);
  }

  /// Enregistre les champs modifiables. Un téléphone vide efface le numéro.
  Future<ProfilUtilisateur> modifier({
    required String prenom,
    required String nom,
    required String email,
    required String telephone,
  }) async {
    final res = await _client.put('/v1/utilisateurs/moi', {
      'firstName': prenom,
      'lastName': nom,
      'email': email,
      'phone': telephone,
    });
    return ProfilUtilisateur.fromJson(res as Map<String, dynamic>);
  }
}
