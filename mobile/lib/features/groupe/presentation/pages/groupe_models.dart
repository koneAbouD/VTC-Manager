class TypeActiviteLocal {
  final int id;
  final String nom;
  final String? description;

  const TypeActiviteLocal({
    required this.id,
    required this.nom,
    this.description,
  });

  factory TypeActiviteLocal.fromJson(Map<String, dynamic> j) =>
      TypeActiviteLocal(
        id: j['id'] as int,
        nom: j['nom'] as String? ?? '',
        description: j['description'] as String?,
      );
}

/// [GestionnaireLocal] représente un utilisateur Keycloak avec le rôle GESTIONNAIRE.
/// Son [id] est l'UUID Keycloak (String), utilisé comme [userId] lors de l'affectation.
class GestionnaireLocal {
  final String id; // UUID Keycloak
  final String username;
  final String? firstName;
  final String? lastName;
  final String? email;

  const GestionnaireLocal({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.email,
  });

  String get displayName {
    final full = [firstName, lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ')
        .trim();
    return full.isNotEmpty ? full : username;
  }

  /// Depuis [UserInfoDto] backend (GET /api/v1/utilisateurs/gestionnaires)
  factory GestionnaireLocal.fromJson(Map<String, dynamic> j) =>
      GestionnaireLocal(
        id: j['id'] as String? ?? '',
        username: j['username'] as String? ?? '',
        firstName: j['firstName'] as String?,
        lastName: j['lastName'] as String?,
        email: j['email'] as String?,
      );

  /// Depuis la réponse imbriquée dans [GroupeVehiculeResponse]
  factory GestionnaireLocal.fromGroupeJson(Map<String, dynamic> j) =>
      GestionnaireLocal(
        id: j['userId'] as String? ?? '',
        username: j['username'] as String? ?? j['userId'] as String? ?? '',
      );
}

class GroupeLocal {
  final int? id;
  final String nom;
  final GestionnaireLocal? gestionnaire;
  final int nbVehicules;

  const GroupeLocal({
    this.id,
    required this.nom,
    this.gestionnaire,
    this.nbVehicules = 0,
  });

  GroupeLocal copyWith({GestionnaireLocal? gestionnaire}) => GroupeLocal(
        id: id,
        nom: nom,
        gestionnaire: gestionnaire ?? this.gestionnaire,
        nbVehicules: nbVehicules,
      );

  /// Depuis [GroupeVehiculeResponse] backend
  factory GroupeLocal.fromJson(Map<String, dynamic> j) {
    final gJson = j['gestionnaire'] as Map<String, dynamic>?;
    return GroupeLocal(
      id: j['id'] as int?,
      nom: j['nom'] as String? ?? '',
      gestionnaire: gJson != null
          ? GestionnaireLocal.fromGroupeJson(gJson)
          : null,
      nbVehicules: j['nbVehicules'] as int? ?? 0,
    );
  }

  /// Corps de la requête POST /api/v1/groupes
  Map<String, dynamic> toCreateJson() => {
        'nom': nom,
        'statut': 'ACTIF',
      };
}