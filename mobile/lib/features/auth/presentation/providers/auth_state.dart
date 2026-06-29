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
  final String username;
  const AuthAuthenticated(this.username);
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
