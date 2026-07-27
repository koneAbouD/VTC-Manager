/// État de l'authentification — sealed class pour exhaustivité des switch.
sealed class AuthState {
  const AuthState();
}

/// Session pas encore vérifiée (démarrage de l'app).
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthUnauthenticated extends AuthState {
  /// Message optionnel à présenter (ex. « Session expirée… ») lors d'une
  /// déconnexion subie plutôt que volontaire.
  final String? message;
  const AuthUnauthenticated([this.message]);
}

class AuthAuthenticated extends AuthState {
  /// Prénom à présenter, jamais le numéro de téléphone qui sert d'identifiant.
  final String? displayName;
  const AuthAuthenticated([this.displayName]);
}

/// Session ouverte mais mise sous clé : seul le code d'accès peut ressortir les
/// tokens du coffre chiffré. L'utilisateur n'a pas à repasser par l'OTP.
class AuthLocked extends AuthState {
  final String? displayName;
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
/// tout neuf sans que le chauffeur ait à changer de code.
class AuthPinResume extends AuthState {
  final String? displayName;
  const AuthPinResume({this.displayName});
}
