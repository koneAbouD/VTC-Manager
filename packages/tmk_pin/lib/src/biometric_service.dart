import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Modalité biométrique proposée par l'appareil.
///
/// Android ne dit pas toujours laquelle il utilise (l'API se contente souvent
/// d'une classe de robustesse), d'où [BiometricKind.generique] : on parle alors
/// de « déverrouillage biométrique » sans nommer le capteur.
enum BiometricKind { visage, empreinte, iris, generique }

/// Ce que l'appareil sait faire, une fois croisés l'OS, le matériel et ce que
/// l'utilisateur a effectivement enrôlé.
@immutable
class BiometricAvailability {
  /// Vrai si une authentification biométrique peut aboutir maintenant.
  final bool disponible;

  final BiometricKind kind;

  /// Nom donné à la modalité dans l'interface (« Face ID », « empreinte
  /// digitale »…), accordé au vocabulaire de la plateforme.
  final String libelle;

  /// Pourquoi c'est indisponible, quand ça l'est et que ça vaut la peine de le
  /// dire (matériel présent mais rien d'enrôlé, par exemple). `null` si
  /// l'appareil n'a tout simplement pas de capteur : inutile d'en parler.
  final String? raison;

  const BiometricAvailability({
    required this.disponible,
    required this.kind,
    required this.libelle,
    this.raison,
  });

  static const indisponible = BiometricAvailability(
    disponible: false,
    kind: BiometricKind.generique,
    libelle: 'Déverrouillage biométrique',
  );

  /// Icône du bouton, choisie sur la modalité réelle.
  IconData get icone => switch (kind) {
        BiometricKind.visage => Icons.face_rounded,
        BiometricKind.iris => Icons.remove_red_eye_rounded,
        BiometricKind.empreinte || BiometricKind.generique =>
          Icons.fingerprint_rounded,
      };

  /// « Face ID » se dit sans article, « l'empreinte digitale » en prend un :
  /// de quoi composer des phrases correctes sans casse-tête à l'appel.
  String get libelleAvecArticle {
    // Sur iOS, Face ID et Touch ID sont des noms propres.
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (ios &&
        (kind == BiometricKind.visage || kind == BiometricKind.empreinte)) {
      return libelle;
    }
    return switch (kind) {
      BiometricKind.visage || BiometricKind.iris => 'la $libelle',
      BiometricKind.empreinte => 'l\'$libelle',
      BiometricKind.generique => 'le $libelle',
    };
  }
}

/// Issue d'une demande d'authentification biométrique.
sealed class BiometricOutcome {
  const BiometricOutcome();
}

/// L'OS a reconnu l'utilisateur.
class BiometricAccepted extends BiometricOutcome {
  const BiometricAccepted();
}

/// L'utilisateur a renoncé (annulation, bascule vers le code, mise en fond).
/// Rien à signaler : il a simplement choisi de saisir son code.
class BiometricDismissed extends BiometricOutcome {
  const BiometricDismissed();
}

/// La biométrie n'a pas pu servir. [message] est affichable tel quel.
///
/// [definitif] distingue ce qui ne se résoudra pas tout seul (plus aucune
/// empreinte enrôlée, capteur absent) de ce qui est passager (verrouillage
/// après trop d'essais) : dans le premier cas, l'appelant désactive l'option
/// au lieu de la proposer en vain à chaque ouverture.
class BiometricUnavailable extends BiometricOutcome {
  final String message;
  final bool definitif;

  const BiometricUnavailable(this.message, {this.definitif = false});
}

/// Accès à la biométrie de l'appareil : détection des capacités et demande
/// d'authentification, avec des messages en français.
///
/// Le service ne connaît rien du code d'accès : il se contente de dire si l'OS
/// a reconnu l'utilisateur. C'est [PinService] qui décide ce que cela ouvre.
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  /// Aucune plateforme web n'expose de biométrie à Flutter : l'app gestionnaire
  /// tourne aussi sur Chrome, où tout appel au greffon lèverait une exception.
  static bool get _plateformeSupportee =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Les deux systèmes ne composent pas la même fenêtre : Android la bâtit
  /// ligne par ligne (titre, sous-titre, description), iOS n'en a qu'une.
  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Ce que cet appareil peut proposer, ici et maintenant.
  ///
  /// Ne lève jamais : un appareil sans capteur, un greffon absent ou une
  /// plateforme non gérée donnent tous [BiometricAvailability.indisponible].
  Future<BiometricAvailability> availability() async {
    if (!_plateformeSupportee) return BiometricAvailability.indisponible;

    try {
      // `canCheckBiometrics` = matériel présent ; `isDeviceSupported` = l'OS
      // accepte une authentification locale (verrou d'écran configuré).
      final materiel = await _auth.canCheckBiometrics;
      final supporte = await _auth.isDeviceSupported();
      if (!materiel || !supporte) return BiometricAvailability.indisponible;

      // Liste vide malgré du matériel : rien n'est enrôlé. On le dit, car
      // c'est à un geste près dans les réglages du téléphone.
      final enroles = await _auth.getAvailableBiometrics();
      if (enroles.isEmpty) {
        return BiometricAvailability(
          disponible: false,
          kind: BiometricKind.generique,
          libelle: _libelle(BiometricKind.generique),
          raison: 'Aucune donnée biométrique n\'est enregistrée sur cet '
              'appareil. Ajoutez-en dans les réglages du téléphone.',
        );
      }

      final kind = _kind(enroles);
      return BiometricAvailability(
        disponible: true,
        kind: kind,
        libelle: _libelle(kind),
      );
    } on LocalAuthException {
      return BiometricAvailability.indisponible;
    } on MissingPluginException {
      return BiometricAvailability.indisponible;
    } on PlatformException {
      return BiometricAvailability.indisponible;
    }
  }

  /// Demande à l'OS d'authentifier l'utilisateur.
  ///
  /// [raison] est la phrase affichée dans la fenêtre système (obligatoire sur
  /// iOS). Seule la biométrie est acceptée : le repli vers le code de
  /// verrouillage du téléphone n'aurait pas de sens, l'application a le sien.
  ///
  /// La fenêtre Android est réduite à une seule ligne de texte. Le titre ne
  /// pouvant pas être omis — `androidx.biometric` (1.1.0, la version qu'embarque
  /// local_auth) refuse de construire la fenêtre sans lui —, c'est lui qui
  /// porte [raison] ; sous-titre et description s'effacent derrière.
  ///
  /// Le bandeau du haut — icône et nom de l'application — reste, lui, et il n'y
  /// a rien à y faire : depuis Android 15 c'est le système qui le pose, et
  /// aucune API ne l'enlève. C'est délibéré côté Android, qui tient à ce que
  /// l'utilisateur voie toujours à qui il donne son empreinte.
  Future<BiometricOutcome> authenticate({required String raison}) async {
    if (!_plateformeSupportee) {
      return const BiometricUnavailable(
        'Le déverrouillage biométrique n\'est pas disponible ici.',
        definitif: true,
      );
    }

    try {
      final reconnu = await _auth.authenticate(
        // Sur iOS, [raison] est le texte de la fenêtre Face ID, rien d'autre ne
        // s'affiche. Sur Android, le plugin la range en description, sous le
        // titre : comme c'est le titre qui la porte désormais, la description
        // reçoit à son tour un espace. Vide, elle ferait sauter l'`assert` du
        // plugin, qui exige une raison non vide.
        localizedReason: _android ? ' ' : raison,
        biometricOnly: true,
        // Une mise en arrière-plan pendant l'invite (notification, appel) ne
        // doit pas compter comme un refus : l'invite reprend au retour.
        persistAcrossBackgrounding: true,
        // `false` = `setConfirmationRequired(false)` côté Android : la
        // reconnaissance du visage ouvre l'application, sans le « Confirmer »
        // que le système intercale sinon. Ce garde-fou vise les transactions
        // sensibles — un paiement déclenché par un regard distrait ; ici le
        // geste est délibéré, l'utilisateur vient d'appuyer sur le bouton de
        // déverrouillage. Sans effet sur l'empreinte, qui suppose un contact.
        sensitiveTransaction: false,
        authMessages: [
          AndroidAuthMessages(
            // Le titre est la seule ligne qu'AndroidX impose : autant qu'elle
            // dise ce qu'on attend de l'utilisateur plutôt qu'un intitulé de
            // plus, le nom de l'application figurant déjà dans le bandeau posé
            // par le système.
            signInTitle: raison,
            // Sous-titre vide, et non omis : l'omettre ferait retomber le
            // plugin sur son défaut, « Verify identity », en anglais. AndroidX
            // masque la ligne quand elle est vide.
            signInHint: '',
            cancelButton: 'Utiliser mon code',
          ),
          const IOSAuthMessages(
            cancelButton: 'Utiliser mon code',
            // Chaîne vide = pas de bouton de repli système : le repli, c'est
            // le pavé numérique déjà à l'écran.
            localizedFallbackTitle: '',
          ),
        ],
      );
      // `false` sans exception : l'OS n'a pas reconnu l'utilisateur, sans autre
      // conséquence. Il peut réessayer ou saisir son code.
      return reconnu ? const BiometricAccepted() : const BiometricDismissed();
    } on LocalAuthException catch (e) {
      return _traduire(e.code);
    } on MissingPluginException {
      return const BiometricUnavailable(
        'Le déverrouillage biométrique n\'est pas disponible sur cet appareil.',
        definitif: true,
      );
    } on PlatformException {
      return const BiometricUnavailable(
        'Le déverrouillage biométrique a échoué. Saisissez votre code TMK.',
      );
    }
  }

  BiometricOutcome _traduire(LocalAuthExceptionCode code) => switch (code) {
        // Renoncements : l'utilisateur (ou le système) a interrompu, il reste
        // le pavé numérique. Inutile d'afficher quoi que ce soit.
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.userRequestedFallback ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.authInProgress =>
          const BiometricDismissed(),

        // Plus rien à reconnaître : l'option ne peut plus servir telle quelle.
        LocalAuthExceptionCode.noBiometricsEnrolled =>
          const BiometricUnavailable(
            'Aucune donnée biométrique n\'est enregistrée sur cet appareil. '
            'Saisissez votre code TMK.',
            definitif: true,
          ),
        LocalAuthExceptionCode.noCredentialsSet => const BiometricUnavailable(
            'Aucun verrouillage n\'est configuré sur cet appareil. '
            'Saisissez votre code TMK.',
            definitif: true,
          ),
        LocalAuthExceptionCode.noBiometricHardware => const BiometricUnavailable(
            'Cet appareil ne dispose pas de capteur biométrique.',
            definitif: true,
          ),

        // Passager : le capteur revient, ou l'utilisateur déverrouille son
        // téléphone. On garde l'option.
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          const BiometricUnavailable(
            'Le capteur biométrique est momentanément indisponible. '
            'Saisissez votre code TMK.',
          ),
        LocalAuthExceptionCode.temporaryLockout => const BiometricUnavailable(
            'Trop de tentatives biométriques. Saisissez votre code TMK.',
          ),
        LocalAuthExceptionCode.biometricLockout => const BiometricUnavailable(
            'La biométrie est bloquée jusqu\'au prochain déverrouillage de '
            'votre téléphone. Saisissez votre code TMK.',
          ),

        LocalAuthExceptionCode.uiUnavailable ||
        LocalAuthExceptionCode.deviceError ||
        LocalAuthExceptionCode.unknownError =>
          const BiometricUnavailable(
            'Le déverrouillage biométrique a échoué. Saisissez votre code TMK.',
          ),
      };

  /// Modalité retenue quand plusieurs sont enrôlées : le visage prime, c'est
  /// le geste le plus immédiat et celui qu'annonce l'appareil (Face ID).
  static BiometricKind _kind(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) return BiometricKind.visage;
    if (types.contains(BiometricType.fingerprint)) {
      return BiometricKind.empreinte;
    }
    if (types.contains(BiometricType.iris)) return BiometricKind.iris;
    // `strong` / `weak` : Android connaît la robustesse, pas le capteur.
    return BiometricKind.generique;
  }

  /// Vocabulaire de la plateforme : sur iOS on dit Face ID et Touch ID, pas
  /// « reconnaissance faciale ».
  static String _libelle(BiometricKind kind) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return switch (kind) {
      BiometricKind.visage => ios ? 'Face ID' : 'reconnaissance faciale',
      BiometricKind.empreinte => ios ? 'Touch ID' : 'empreinte digitale',
      BiometricKind.iris => 'reconnaissance de l\'iris',
      BiometricKind.generique => 'déverrouillage biométrique',
    };
  }
}
