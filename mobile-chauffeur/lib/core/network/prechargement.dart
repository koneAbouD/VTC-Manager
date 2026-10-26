import 'api_client.dart';

/// Écrans lus d'avance, pour être servis hors connexion même si le
/// chauffeur ne les a pas ouverts : son compte et tout ce qui le compose.
///
/// Chaque lecture doit être celle de l'écran : le cache retrouve une réponse
/// par son URL exacte.
Future<void> prechargerEcransCles(ApiClient client) async {
  const lectures = [
    '/me/profil',
    '/me/solde',
    '/me/operations',
    '/me/recettes',
    '/me/cotisations',
    '/me/penalites',
    '/me/contraventions',
    '/me/indisponibilites',
    '/me/notifications',
  ];
  // Une lecture à la fois : le réseau mobile reste disponible pour les écrans.
  for (final path in lectures) {
    if (!await client.precharger(path)) return;
  }
}
