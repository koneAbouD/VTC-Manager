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

/// Connexion réussie, code d'accès à choisir avant d'entrer dans l'application.
class AuthPinSetup extends AuthState {
  final String? displayName;

  const AuthPinSetup({this.displayName});
}

/// Connexion réussie alors qu'un code existe déjà pour ce compte : on le
/// redemande au lieu d'en faire choisir un nouveau.
///
/// La saisie sert à re-dériver la clé du coffre, pour y ranger le refresh token
/// tout neuf sans que l'utilisateur ait à changer de code.
class AuthPinResume extends AuthState {
  final String? displayName;

  const AuthPinResume({this.displayName});
}

class AuthUnauthenticated extends AuthState {
  /// Message optionnel à présenter (ex. « Session expirée… ») lors d'une
  /// déconnexion subie plutôt que volontaire.
  final String? message;
  const AuthUnauthenticated([this.message]);
}

class AuthError extends AuthState {
  final String message;

  /// Vrai quand le serveur n'a pas tranché la demande : réseau coupé, délai
  /// dépassé, service d'authentification en panne. La saisie n'est alors pas en
  /// cause — l'écran la conserve au lieu de la vider, à l'image du
  /// déverrouillage hors ligne qui ne consomme aucun essai (voir
  /// `UnlockOffline`).
  final bool indisponible;

  const AuthError(this.message, {this.indisponible = false});
}
