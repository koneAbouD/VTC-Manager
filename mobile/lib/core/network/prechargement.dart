import '../../features/tableau_bord/data/datasources/tableau_bord_remote_datasource.dart';
import 'api_client.dart';

/// Écrans lus d'avance, pour être servis hors connexion même si le
/// gestionnaire ne les a pas ouverts : la flotte, le tableau de bord du mois,
/// la trésorerie, et les référentiels des formulaires et des filtres.
///
/// Chaque lecture doit être celle de l'écran, paramètres compris : le cache
/// retrouve une réponse par son URL exacte.
Future<void> prechargerEcransCles(ApiClient client) async {
  final maintenant = DateTime.now();
  final lectures = <(String, Map<String, String>?)>[
    ('/vehicules', null),
    ('/chauffeurs', null),
    (
      '/tableau-bord',
      TableauBordRemoteDatasource.requete(
          maintenant.year, maintenant.month, 'CAISSE', null, null),
    ),
    ('/comptes-tresorerie', {'actifsSeulement': 'true'}),
    ('/v1/statuts-vehicule', null),
    ('/v1/types-vehicules/actifs', null),
    ('/v1/types-activites/actifs', null),
    ('/v1/groupes', null),
    ('/conditions-travail', null),
    ('/parametres', null),
  ];
  // Une lecture à la fois : le réseau mobile reste disponible pour les écrans.
  for (final (path, query) in lectures) {
    if (!await client.precharger(path, query: query)) return;
  }
}
