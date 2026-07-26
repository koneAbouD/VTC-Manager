/// État de l'authentification — sealed class pour exhaustivité des switch.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  /// Nom à présenter à l'utilisateur (prénom si connu), pas l'identifiant de
  /// connexion — celui-ci se lit dans le jeton quand il est nécessaire.
  final String displayName;

  const AuthAuthenticated(this.displayName);
}

/// Session ouverte mais mise sous clé : les tokens ne sont plus disponibles en
/// clair, seul le code d'accès peut les ressortir du coffre chiffré.
///
/// Distinct de [AuthUnauthenticated] : l'utilisateur n'a pas à ressaisir ses
/// identifiants, cinq chiffres suffisent.
class AuthLocked extends AuthState {
  /// Prénom à afficher (`null` si inconnu : l'écran salue sans nommer).
  final String? displayName;

  /// Motif du verrouillage, à présenter discrètement (« … pour inactivité »).
  final String? message;

  const AuthLocked({this.displayName, this.message});
}

/// Connexion réussie, code d'accès proposé avant d'entrer dans l'application.
class AuthPinSetup extends AuthState {
  final String? displayName;

  const AuthPinSetup({this.displayName});
}

class AuthUnauthenticated extends AuthState {
  /// Message optionnel à présenter (ex. « Session expirée… ») lors d'une
  /// déconnexion subie plutôt que volontaire.
  final String? message;
  const AuthUnauthenticated([this.message]);
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}
