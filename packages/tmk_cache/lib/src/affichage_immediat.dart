/// Affiche la dernière réponse connue en attendant celle du serveur.
///
/// Sur réseau mobile, une liste met plusieurs secondes à arriver ; l'écran
/// montre entre-temps ce qu'il montrait la dernière fois au lieu d'un
/// indicateur de chargement. [enAttente] est la lecture déjà lancée : si elle
/// aboutit avant que le cache soit lu, [afficher] n'est pas appelé — on
/// n'écrase jamais la réponse fraîche par l'ancienne.
///
/// À réserver au premier affichage d'un écran : sur un rafraîchissement,
/// l'écran montre déjà des données au moins aussi récentes que le cache.
///
/// Une erreur de lecture du cache est ignorée : l'écran attend le serveur,
/// comme sans cache. Un cache plus lent que le serveur n'est pas attendu.
Future<void> afficherEnAttendant<T>({
  required Future<Object?> enAttente,
  required Future<T?> Function() cache,
  required void Function(T donnees) afficher,
}) async {
  var arrivee = false;
  final serveur = enAttente.then<T?>(
    (_) {
      arrivee = true;
      return null;
    },
    onError: (Object _) {
      arrivee = true;
      return null;
    },
  );
  T? enCache;
  try {
    enCache = await Future.any([cache(), serveur]);
  } catch (_) {
    return;
  }
  if (enCache != null && !arrivee) afficher(enCache);
}
