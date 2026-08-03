/// Dépôt et retrait du jeton d'appareil auprès du backend.
///
/// Le package ne connaît ni les URL ni la manière dont chaque application
/// s'authentifie : les deux n'appellent pas les mêmes routes — `/api/devices`
/// pour le gestionnaire, `/api/me/devices` pour le chauffeur. Chacune fournit
/// donc son implémentation, adossée à son propre client HTTP.
abstract class PushRegistrar {
  /// Déclare l'appareil pour le compte connecté.
  ///
  /// [plateforme] vaut `ANDROID` ou `IOS`, comme l'attend le backend.
  Future<void> enregistrer({
    required String token,
    required String plateforme,
  });

  /// Retire l'appareil, à la déconnexion.
  ///
  /// À appeler tant que la session est encore valide : une fois le jeton
  /// d'accès révoqué, la requête serait rejetée et l'appareil continuerait de
  /// recevoir les notifications d'un compte qui n'y est plus connecté.
  Future<void> revoquer(String token);
}
