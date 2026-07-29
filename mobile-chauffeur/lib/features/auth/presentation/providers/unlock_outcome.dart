/// Issue d'une saisie de code sur l'écran de verrouillage, du point de vue de
/// l'interface.
///
/// Traduit le résultat cryptographique du paquet `tmk_pin` en cas d'usage,
/// notamment l'échec réseau — un bon code alors que le serveur est injoignable
/// n'est ni une erreur de saisie, ni une session perdue.
sealed class UnlockOutcome {
  const UnlockOutcome();
}

/// Code correct et session rouverte : l'application s'ouvre.
class UnlockOk extends UnlockOutcome {
  const UnlockOk();
}

/// Code erroné.
class UnlockWrong extends UnlockOutcome {
  final int remainingAttempts;
  const UnlockWrong(this.remainingAttempts);
}

/// Trop d'échecs récents : il faut patienter avant de réessayer.
class UnlockWait extends UnlockOutcome {
  final Duration remaining;
  const UnlockWait(this.remaining);
}

/// Code correct mais serveur injoignable : on reste verrouillé, sans compter
/// d'échec.
class UnlockOffline extends UnlockOutcome {
  final String message;
  const UnlockOffline(this.message);
}

/// La biométrie n'a pas abouti : rien n'est ouvert, le pavé numérique reste
/// le chemin normal.
///
/// [message] vaut `null` quand l'utilisateur a simplement renoncé (annulation,
/// bascule volontaire vers le code) : il n'y a alors rien à lui expliquer.
class UnlockBiometricsFailed extends UnlockOutcome {
  final String? message;
  const UnlockBiometricsFailed([this.message]);
}

/// Le code a été abandonné (essais épuisés ou session révoquée côté serveur) :
/// retour à la connexion complète.
class UnlockRequiresLogin extends UnlockOutcome {
  final String? message;
  const UnlockRequiresLogin([this.message]);
}
