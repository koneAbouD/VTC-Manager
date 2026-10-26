/// Cache local partagé par les applications TMK.
///
/// La dernière réponse de chaque lecture est rejouée quand le serveur est
/// injoignable (un bandeau dit de quand datent les données), revalidée par
/// son ETag, et affichée en attendant le serveur. Les images restent sur le
/// disque.
library tmk_cache;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'src/etat_hors_ligne.dart';
import 'src/images.dart';
import 'src/reponse_cache.dart';

export 'src/affichage_immediat.dart';
export 'src/bandeau_hors_ligne.dart';
export 'src/chiffreur_cache.dart' show ChiffreurCache;
export 'src/diagnostic_reseau.dart';
export 'src/etat_hors_ligne.dart';
export 'src/images.dart' show cacheImages, cleImage, imageReseau;
export 'src/prechargement_periodique.dart';
export 'src/reponse_cache.dart';
export 'src/stockage_reponses.dart';

/// Déconnexion : réponses, images et bandeau, rien ne survit à la session.
///
/// Lancée sans être attendue : la déconnexion ne dépend pas d'un disque lent.
/// Une purge interrompue ne livre rien au compte suivant, dont la première
/// réponse efface celles de l'ancien titulaire (voir [ReponseCache.ecrire]).
///
/// La zone isole les erreurs du cache d'images, qui ouvre sa base dès sa
/// construction et laisserait sinon échapper un échec d'ouverture.
void purgerCacheSession() {
  EtatHorsLigne.instance.serveurJoignable();
  runZonedGuarded(
    () async {
      await ReponseCache.instance.vider();
      await cacheImages.emptyCache();
    },
    (e, _) => debugPrint('tmk_cache : purge incomplète ($e)'),
  );
}
