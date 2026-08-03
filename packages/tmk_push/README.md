# tmk_push

Notifications push (Firebase Cloud Messaging) partagées par `mobile`
(gestionnaire) et `mobile-chauffeur`.

Le package ne connaît ni les URL du backend ni la façon dont chaque application
s'authentifie : il orchestre le cycle de vie du jeton d'appareil et la réception
des messages, chaque application fournissant son `PushRegistrar`.

## Ce que fait le package

```
Connexion réussie
  getToken() → PushRegistrar.enregistrer(token, plateforme)
  puis écoute onTokenRefresh → réenregistre à chaque rotation

Message reçu
  application au premier plan  → messagesAuPremierPlan (rien ne s'affiche seul)
  notification touchée         → DeepLinkQueue
  application fermée puis
  relancée par la notification → getInitialMessage() → DeepLinkQueue

Déconnexion
  PushRegistrar.revoquer(token), AVANT la révocation de la session
```

## Le verrou change tout

Les applications TMK se remettent sous clé dès qu'elles passent en arrière-plan
un peu longtemps. Toucher une notification ramène donc presque toujours sur
l'écran du code d'accès, et non sur la page visée.

`DeepLinkQueue` retient le lien jusqu'au déverrouillage plutôt que de naviguer
dans le vide — ou pire, d'afficher la page derrière la saisie du code. Un seul
lien est conservé : quand plusieurs notifications s'empilent, seule la dernière
touchée intéresse l'utilisateur.

L'application pilote cet état :

```dart
PushService.instance.marquerPrete();       // session déverrouillée
PushService.instance.marquerVerrouillee(); // remise sous clé
```

## Confidentialité de la charge utile

Le backend n'envoie que des identifiants — type, numéro de notification, objet
visé. Aucun montant, aucun nom, aucune immatriculation : une notification
s'affiche sur l'écran verrouillé, en dehors du code d'accès censé protéger ces
données. Le détail se charge à l'ouverture, une fois l'utilisateur identifié.

## Branchement dans une application

```dart
// 1. Au démarrage, avant toute connexion
await PushService.instance.initialiser();

// 2. Après une connexion réussie
await PushService.instance.demanderPermission();
await PushService.instance.attacherSession(MonRegistrar(apiClient));

// 3. Avant de révoquer la session
await PushService.instance.detacherSession();

// 4. Ouverture des écrans
PushService.instance.liens.listen(monRouteur.ouvrir);
```

Le `PushRegistrar` diffère d'une application à l'autre :

| Application | Enregistrement | Révocation |
|---|---|---|
| gestionnaire | `POST /api/devices` | `DELETE /api/devices/{token}` |
| chauffeur | `POST /api/me/devices` | `DELETE /api/me/devices/{token}` |

## Côté natif

Le canal Android `vtc_notifications_default` (`PushService.canalAndroid`) doit
exister et porter le même identifiant que la constante `CANAL_ANDROID` du
backend. Un canal inconnu prive la notification de son son et de sa priorité,
sans la moindre erreur visible.

## Ce que le package ne fait pas

- **Afficher une notification quand l'application est au premier plan.** Android
  ne le fait pas de lui-même, et c'est voulu : l'utilisateur a déjà l'application
  sous les yeux. `messagesAuPremierPlan` laisse chaque application décider —
  bandeau discret, rafraîchissement d'un badge.
- **Rejouer un envoi manqué.** Une notification perdue reste consultable dans le
  centre de notifications ; la faire vibrer des heures plus tard pour un fait
  déjà connu n'apporterait rien.
- **Fonctionner sur le web.** `initialiser()` se retire sans bruit hors Android
  et iOS, pour ne pas casser la compilation web de `mobile`.
