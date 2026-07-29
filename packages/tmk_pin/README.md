# tmk_pin

Code d'accès local (verrou d'application) partagé par `mobile` (gestionnaire) et
`mobile-chauffeur`.

Le code à 5 chiffres **ne remplace pas la connexion** : il rouvre une session
déjà obtenue. Le refresh token n'existe sur l'appareil que chiffré par une clé
dérivée du code — sans le bon code, il n'y a rien d'exploitable à voler.

## Modèle

```
Configuration (après la 1re connexion)
  sel   = 16 octets aléatoires
  clé   = PBKDF2-HMAC-SHA256(code, sel, 50 000 itérations) → 256 bits
  coffre = AES-GCM(refreshToken, clé)
  stocké : sel, nonce, coffre, MAC, compteur d'essais, nom affiché
  jamais stocké : le code, la clé, le refresh token en clair

Déverrouillage
  clé = PBKDF2(code saisi, sel)
  bon code   → le MAC GCM valide → refresh token restitué
  code faux  → le MAC échoue → essai décompté, aucune information ne fuit
```

La clé reste en mémoire tant que la session est déverrouillée : les tokens
renouvelés sont rechiffrés sans redemander le code (`updateRefreshToken`).
`lock()` l'oublie, `reset()` purge tout.

Garde-fous : 5 essais maximum puis purge, temporisation de 5 s / 15 s après le
3ᵉ et le 4ᵉ échec, compteur persistant (un redémarrage de l'app ne le remet pas
à zéro), refus des codes devinables (`00000`, `12345`…), code rattaché à un
compte (`resetIfOtherAccount`).

## Déverrouillage biométrique

Option facultative, greffée sur le même coffre : `enableBiometrics()` range la
clé **dérivée** (jamais le code) dans le Keychain / Keystore, et
`unlockWithBiometrics()` la relit pour ouvrir le coffre sans PBKDF2. Le code
reste le chemin de secours et n'est jamais remplacé.

```
Activation (session déverrouillée, biométrie validée par l'OS)
  stocké : pin_biometric_key = la clé AES du coffre

Déverrouillage
  OS reconnaît l'utilisateur → clé relue → coffre ouvert (instantané)
  OS refuse                  → rien n'est lu, le pavé reprend la main
```

C'est la garantie du magasin de l'OS qui porte l'option, pas la cryptographie
du code : sur un appareil rooté ou jailbreaké, cette clé est extractible là où
un code à 5 chiffres ne l'était pas. Le compromis est assumé — l'option est
facultative, et le coffre reste le seul dépôt du refresh token.

`BiometricService` s'occupe de la détection (matériel, enrôlement, plateforme)
et traduit les codes d'erreur de `local_auth` en messages français ; il ne sait
rien du code d'accès. `BiometricAvailability` fournit le libellé accordé à la
plateforme (« Face ID » sur iOS, « empreinte digitale » sur Android) et l'icône
de la touche.

Cohérence entretenue par `PinService` : `configure()` purge la clé (sel neuf),
`changeCode()` la réinstalle, `lock()` la conserve — c'est ce qui permet de
rouvrir d'un doigt —, `reset()` l'emporte. Une clé qui n'ouvre plus le coffre
est abandonnée d'elle-même.

### Configuration native requise

| Plateforme | À faire | Sans quoi |
|---|---|---|
| Android | `MainActivity : FlutterFragmentActivity` | `BiometricPrompt` ne peut pas s'afficher |
| Android | `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>` | Refus au premier appel |
| Android | minSdk ≥ 24 (défaut Flutter) | `local_auth_android` ne compile pas |
| iOS | `NSFaceIDUsageDescription` dans `Info.plist` | L'app est **tuée** à la première demande Face ID |

Le web n'expose aucune biométrie à Flutter : `BiometricService` y répond
`indisponible` sans jamais appeler le greffon.

## Prérequis backend

Les tokens doivent être émis avec le scope `offline_access` (voir
`KeycloakAuthAdapter`) : sans lui, le refresh token meurt avec la session SSO
(30 min d'inactivité) et le déverrouillage échouerait dès le lendemain.

## Usage

```dart
final pin = PinService(const PinStore(SecureKeyValueStore()));

// Après la première connexion réussie
await pin.configure(
  code: '48213',
  refreshToken: token.refreshToken!,
  account: username,
  displayName: DisplayName.resolve(accessToken: token.accessToken),
);

// Au lancement suivant
switch (await pin.unlock(saisie)) {
  case UnlockSuccess(:final refreshToken): // reprendre la session
  case UnlockFailure(:final remainingAttempts): // afficher les essais restants
  case UnlockThrottled(:final remaining): // patienter
  case UnlockExhausted(): // retour au login complet
}
```

`DisplayName.resolve` choisit le nom de l'écran de verrouillage : prénom métier,
sinon `given_name` du jeton, sinon l'identifiant — **jamais** un identifiant qui
est un numéro de téléphone, comme c'est le cas côté chauffeur.

## Interface

`PinTheme` porte les couleurs (aucune n'est codée en dur), `PinBoxes` les cases
de saisie avec secousse sur erreur, `PinKeypad` le pavé numérique dédié — pas de
clavier système, donc ni suggestion, ni presse-papiers, ni saisie prédictive.

`PinKeypad` accepte une `PinAuxKey` qui occupe l'emplacement vide en bas à
gauche du pavé, là où iOS et Android placent la touche biométrique.

## Plateformes

La dérivation de clé change de stratégie selon la cible (`_derive_io.dart` /
`_derive_web.dart`, choisis par import conditionnel) :

| Cible | Stratégie | Pourquoi |
|---|---|---|
| iOS / Android / bureau | `Isolate.run` | ~250 ms de calcul pur, déportés pour ne pas figer l'interface |
| Navigateur | appel direct | `dart:isolate` **n'existe pas** sur le web (« dart:isolate is not supported on dart4web ») ; Web Crypto exécute PBKDF2 nativement |

⚠️ Ne jamais réintroduire `Isolate.run` dans le chemin commun : l'application
tourne aussi sur Chrome, et l'exception laisserait l'écran de code en
chargement perpétuel.

Sur le web, `flutter_secure_storage` se ramène à `localStorage` avec une clé
rangée juste à côté — le coffre y gagne donc encore plus d'importance
qu'ailleurs : sa clé, elle, n'est stockée nulle part.

## Tests

```bash
flutter test && flutter test --platform chrome
```

Les deux plateformes doivent passer : c'est ce qui garde la compatibilité
navigateur, invisible autrement.
