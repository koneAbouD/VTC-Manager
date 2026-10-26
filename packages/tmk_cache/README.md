# tmk_cache

Cache local partagé par `mobile` (gestionnaire) et `mobile-chauffeur`. C'est la
phase 1 de la consultation hors ligne.

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

Stockage : SQLite via drift (`tmk_cache.sqlite`, isolate dédié) sur mobile, et
la mémoire seule sur le web.

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
