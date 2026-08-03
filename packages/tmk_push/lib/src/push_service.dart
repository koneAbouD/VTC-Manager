import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'deep_link_queue.dart';
import 'push_message.dart';
import 'push_registrar.dart';

/// Reçu en arrière-plan, dans un isolate distinct de l'application.
///
/// Nos messages portent un bloc `notification` : le système les affiche
/// lui-même, sans que ce gestionnaire ait à intervenir. Il n'en reste pas moins
/// obligatoire — sans lui, le plugin avertit à chaque message reçu application
/// fermée. Il ne peut rien faire d'utile de plus : cet isolate n'a accès ni à
/// la session, ni au coffre du code d'accès, ni à l'interface.
@pragma('vm:entry-point')
Future<void> gestionnaireArrierePlan(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Notifications push des applications TMK.
///
/// Trois responsabilités, dans cet ordre d'importance :
///
///  1. tenir à jour le jeton d'appareil côté backend — déposé à la connexion,
///     redéposé à chaque rotation par FCM, retiré à la déconnexion ;
///  2. transformer les messages reçus en [PushMessage] exploitables ;
///  3. différer l'ouverture des liens profonds tant que l'application est sous
///     clé (voir [DeepLinkQueue]).
///
/// L'échec d'une de ces opérations ne doit jamais empêcher l'utilisateur de se
/// connecter ou de se déconnecter : les notifications sont un confort, pas une
/// condition d'accès. Toutes les erreurs sont donc absorbées et journalisées.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Canal de notification Android. Doit correspondre au `CANAL_ANDROID` du
  /// backend et à celui déclaré côté natif : un canal inconnu prive la
  /// notification de son son et de sa priorité, sans erreur visible.
  static const canalAndroid = 'vtc_notifications_default';

  final DeepLinkQueue _liens = DeepLinkQueue();

  final StreamController<PushMessage> _premierPlan =
      StreamController<PushMessage>.broadcast();

  PushRegistrar? _registrar;
  StreamSubscription<String>? _abonnementRotation;
  StreamSubscription<RemoteMessage>? _abonnementPremierPlan;
  StreamSubscription<RemoteMessage>? _abonnementOuverture;

  /// Dernier jeton connu, retenu pour pouvoir le révoquer à la déconnexion :
  /// [FirebaseMessaging.getToken] pourrait ne plus répondre à ce moment-là.
  String? _token;

  bool _initialise = false;

  /// Liens profonds à ouvrir, une fois l'application déverrouillée.
  Stream<PushMessage> get liens => _liens.flux;

  /// Messages reçus alors que l'application est au premier plan.
  ///
  /// Android n'affiche rien dans ce cas — c'est voulu par le système, l'utilisateur
  /// a déjà l'application sous les yeux. À l'application d'en faire ce qu'elle
  /// juge utile : bandeau discret, rafraîchissement d'un badge.
  Stream<PushMessage> get messagesAuPremierPlan => _premierPlan.stream;

  /// Vrai si un lien attend le déverrouillage.
  bool get aUnLienEnAttente => _liens.aUnLienEnAttente;

  /// Prépare Firebase et branche les écoutes. À appeler une fois au démarrage,
  /// avant toute connexion.
  ///
  /// Sans effet hors Android et iOS : les applications se compilent aussi pour
  /// le web, où cette chaîne n'est pas configurée.
  Future<void> initialiser() async {
    if (_initialise || !_plateformeSupportee) return;
    _initialise = true;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(gestionnaireArrierePlan);

      // iOS : sans cela, rien ne s'affiche application ouverte.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _abonnementPremierPlan = FirebaseMessaging.onMessage.listen((message) {
        final push = _convertir(message);
        if (push != null) _premierPlan.add(push);
      });

      // Notification touchée, application déjà lancée.
      _abonnementOuverture =
          FirebaseMessaging.onMessageOpenedApp.listen(_ouvrir);

      // Notification touchée alors que l'application était fermée : le message
      // est rendu une seule fois, au tout premier démarrage qui suit.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _ouvrir(initial);
    } catch (e) {
      debugPrint('[push] initialisation impossible : $e');
    }
  }

  /// Demande l'autorisation d'afficher des notifications.
  ///
  /// Android 13 et plus la réclament explicitement, iOS depuis toujours. Rend
  /// `false` si l'utilisateur refuse — l'application reste parfaitement
  /// utilisable, le centre de notifications continue de tout recenser.
  Future<bool> demanderPermission() async {
    if (!_plateformeSupportee) return false;
    try {
      final reglages = await FirebaseMessaging.instance.requestPermission();
      return reglages.authorizationStatus == AuthorizationStatus.authorized ||
          reglages.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('[push] demande de permission impossible : $e');
      return false;
    }
  }

  /// Rattache l'appareil au compte qui vient de se connecter.
  ///
  /// Reste à l'écoute des rotations de jeton : FCM en émet un nouveau après une
  /// restauration de sauvegarde ou un effacement des données, et l'ancien cesse
  /// alors de livrer sans que rien ne le signale.
  Future<void> attacherSession(PushRegistrar registrar) async {
    if (!_plateformeSupportee) return;
    _registrar = registrar;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _token = token;
        await registrar.enregistrer(token: token, plateforme: _plateforme);
      }
    } catch (e) {
      debugPrint('[push] enregistrement de l\'appareil impossible : $e');
    }

    _abonnementRotation?.cancel();
    _abonnementRotation =
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _token = token;
      try {
        await _registrar?.enregistrer(token: token, plateforme: _plateforme);
      } catch (e) {
        debugPrint('[push] mise à jour du jeton impossible : $e');
      }
    });
  }

  /// Retire cet appareil du compte alors que la session, elle, continue :
  /// l'utilisateur a coupé les notifications depuis les réglages.
  ///
  /// À la différence de [detacherSession], le jeton est redemandé à FCM s'il
  /// n'est pas déjà connu — la coupure peut être appliquée au lancement, avant
  /// toute session poussée, quand l'application se met en conformité avec un
  /// réglage pris la fois précédente.
  ///
  /// Rend `false` si le backend n'a pas confirmé : l'appareil continuera de
  /// recevoir, et il faudra réessayer. À l'appelant de le dire.
  Future<bool> couperReception(PushRegistrar registrar) async {
    _abonnementRotation?.cancel();
    _abonnementRotation = null;
    _registrar = null;
    _liens.vider();

    if (!_plateformeSupportee) return true;

    try {
      final token = _token ?? await FirebaseMessaging.instance.getToken();
      if (token == null) return true; // Aucun appareil déclaré : rien à couper.
      await registrar.revoquer(token);
      _token = token;
      return true;
    } catch (e) {
      debugPrint('[push] coupure impossible : $e');
      return false;
    }
  }

  /// Détache l'appareil du compte, à la déconnexion.
  ///
  /// À appeler **avant** la révocation de la session : la requête a besoin d'un
  /// jeton d'accès encore valide.
  Future<void> detacherSession() async {
    _abonnementRotation?.cancel();
    _abonnementRotation = null;
    _liens.vider();

    final token = _token;
    final registrar = _registrar;
    _registrar = null;

    if (token == null || registrar == null) return;
    try {
      await registrar.revoquer(token);
    } catch (e) {
      // La déconnexion locale prime : mieux vaut une ligne orpheline côté
      // serveur qu'un utilisateur bloqué sur son écran de session.
      debugPrint('[push] révocation de l\'appareil impossible : $e');
    }
  }

  /// L'application est déverrouillée : un lien en attente peut s'ouvrir.
  void marquerPrete() => _liens.marquerPrete();

  /// L'application se remet sous clé.
  void marquerVerrouillee() => _liens.marquerVerrouillee();

  void _ouvrir(RemoteMessage message) {
    final push = _convertir(message);
    if (push != null) _liens.deposer(push);
  }

  PushMessage? _convertir(RemoteMessage message) => PushMessage.depuisCharge(
        message.data,
        titre: message.notification?.title,
        corps: message.notification?.body,
      );

  static bool get _plateformeSupportee =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get _plateforme =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

  @visibleForTesting
  Future<void> fermer() async {
    await _abonnementRotation?.cancel();
    await _abonnementPremierPlan?.cancel();
    await _abonnementOuverture?.cancel();
    await _premierPlan.close();
    await _liens.fermer();
  }
}
