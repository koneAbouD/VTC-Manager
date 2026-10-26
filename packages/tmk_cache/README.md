# tmk_cache

Cache local partagé par `mobile` (gestionnaire) et `mobile-chauffeur` :
consultation hors ligne, revalidation par ETag, affichage immédiat des écrans
et préchargement.

## Réponses de l'API

Chaque lecture (`GET`) réussie devient la réponse de secours de son URL. Quand
le serveur est hors d'atteinte (pas de réseau, portail Wi-Fi qui redirige, 502,
503 ou 504), `ApiClient.get` rejoue cette réponse au lieu de lever l'erreur.

- **Le serveur l'emporte toujours.** Une réponse du serveur, même une erreur
  (403, 404, 409…), n'est jamais masquée par le cache.
- **Seules les lectures sont concernées.** Les écritures échouent hors
  connexion comme avant, et `/auth/*` n'est jamais mis en cache.
- **Durée limitée.** Au-delà de 30 jours, une réponse n'est plus servie. La
  base garde au plus 500 réponses, les plus récentes.
- **Chiffrement.** Les réponses sont chiffrées en AES-GCM avec une clé tirée au
  hasard et rangée dans le stockage sécurisé. L'URL n'est stockée que hachée.
- **Un compte à la fois.** Une réponse n'est servie qu'au compte (`sub`) qui
  l'a reçue. La première réponse d'un nouveau compte efface celles du
  précédent, et la déconnexion vide tout (`purgerCacheSession`).
- **Jamais bloquant.** Une erreur de stockage ou de chiffrement est avalée, et
  l'appel se comporte comme s'il n'y avait pas de cache.

Stockage : SQLite via drift (`tmk_cache.sqlite`, isolate dédié, schéma 2) sur
mobile, et la mémoire seule sur le web. Une seule table de réponses : les écrans
lisent des listes complètes qu'ils filtrent en mémoire, la réponse rejouée
suffit donc à les servir hors connexion, filtres et recherche compris.

Dans les tests des applications, la base ne répond pas : chaque app remplace
`ReponseCache.instance` par un cache en mémoire dans
`test/flutter_test_config.dart`.

## Revalidation (ETag)

Le backend pose un ETag faible sur chaque lecture de `/api/*`
(`EtagLecturesFilter`) et compresse le JSON en gzip. `ApiClient` renvoie l'ETag
de la réponse en cache (`If-None-Match`). Si rien n'a changé, le serveur répond
304 sans corps : la réponse en cache sert et sa date est rafraîchie. Une
lecture du cache qui tarde au-delà de 500 ms est abandonnée, et la requête part
alors sans condition.

## Affichage immédiat

`ApiClient.lireCache` rend la dernière réponse sans appeler le serveur ni
toucher au bandeau. `afficherEnAttendant` l'affiche pendant que la lecture
réseau, déjà lancée, est en cours. Une réponse fraîche n'est jamais écrasée par
l'ancienne, et un rafraîchissement garde ce que l'écran montre déjà. Écrans
branchés :

- gestionnaire : véhicules et chauffeurs (flotte), tableau de bord, et toutes
  les listes paginées (`PagedListNotifier`, liste des opérations) ;
- chauffeur : profil, solde et opérations (accueil).

Pour les listes paginées, pas de variante « cache » par écran :
`ApiClient.depuisLeCacheSeul` rejoue le fetcher ordinaire de l'écran dans une
zone où chaque `get` lit le cache au lieu du serveur. Un double de test qui ne
passe pas par l'`ApiClient` consulte `ApiClient.lectureCacheSeul` pour se
comporter comme un cache vide.

## Préchargement

`PrechargementPeriodique` enveloppe l'accueil des deux apps. Il lit d'avance
les écrans clés (`core/network/prechargement.dart` de chaque app) trois
secondes après l'ouverture de la session, puis à chaque retour au premier
plan, au plus une fois par quart d'heure. Les lectures partent une par une et
s'arrêtent dès que le serveur est hors d'atteinte, sans bandeau ni erreur.
Chaque lecture doit reprendre l'URL exacte de l'écran, paramètres compris.

## Bandeau

`EtatHorsLigne` retient l'heure de la plus ancienne donnée servie depuis le
cache, et la première réponse du serveur le remet à zéro. `BandeauHorsLigne`,
posé dans `MaterialApp.builder`, affiche par exemple « Hors connexion · données
de 14:32 ».

## Images

`Image(image: imageReseau(url, headers: …))` remplace `Image.network`. Les
images sont gardées sur disque dans un cache dédié, vidé à la déconnexion. La
clé ignore la signature des URL présignées MinIO (`X-Amz-*`), mais conserve
les paramètres comme `?v=3`.
