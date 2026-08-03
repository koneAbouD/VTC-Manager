import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_push/tmk_push.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../../auth/presentation/providers/auth_state.dart';
import '../../cotisation/presentation/pages/lignes_cotisation_page.dart';
import '../../maintenance/presentation/pages/lignes_maintenance_page.dart';
import '../../recette/presentation/pages/lignes_recette_page.dart';
import 'notification_style.dart';
import 'pages/notifications_page.dart';
import 'providers/notification_providers.dart';

/// Ouvre l'écran concerné lorsqu'une notification est touchée.
///
/// S'intercale sous l'application pour disposer du navigateur racine. Les liens
/// ne lui parviennent qu'une fois la session déverrouillée : c'est
/// [PushService] qui les retient jusque-là, de sorte que ce routeur n'a jamais
/// à se demander si l'écran de code est affiché.
class PushRouter extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const PushRouter({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  @override
  ConsumerState<PushRouter> createState() => _PushRouterState();
}

class _PushRouterState extends ConsumerState<PushRouter>
    with WidgetsBindingObserver {
  StreamSubscription<PushMessage>? _liens;
  StreamSubscription<PushMessage>? _premierPlan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _liens = PushService.instance.liens.listen(_ouvrir);
    _premierPlan = PushService.instance.messagesAuPremierPlan.listen(_annoncer);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liens?.cancel();
    _premierPlan?.cancel();
    super.dispose();
  }

  /// Rattrape ce qui est arrivé pendant l'absence.
  ///
  /// Une notification reçue application en arrière-plan n'alimente aucun flux :
  /// le système l'affiche seul, dans un isolate qui ne connaît ni la session ni
  /// l'interface. Sans ce rattrapage, le centre et son badge resteraient sur
  /// l'état lu à la dernière ouverture — c'est-à-dire vides pour quelqu'un qui
  /// vient pourtant de recevoir une alerte sur son écran de verrouillage.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Sous clé, les jetons d'accès sont effacés : l'appel échouerait et
    // remplacerait une liste valide par une erreur. La reprise de session s'en
    // charge juste après, à la saisie du code.
    if (ref.read(authNotifierProvider) is! AuthAuthenticated) return;
    ref.invalidate(centreNotificationsProvider);
  }

  /// Notification reçue application ouverte.
  ///
  /// Android n'affiche rien de lui-même dans ce cas : sans ce bandeau,
  /// l'événement ne se manifesterait que par un compteur qui change au fond de
  /// l'écran des réglages — autant dire pas du tout.
  void _annoncer(PushMessage message) {
    // Le compteur de non-lues vient de changer, quoi qu'on affiche.
    ref.invalidate(centreNotificationsProvider);

    // Sous clé, l'écran de code est affiché : le texte de la notification n'a
    // rien à faire par-dessus, c'est précisément ce dont le code protège.
    if (ref.read(authNotifierProvider) is! AuthAuthenticated) return;

    final overlay = widget.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    afficherBannierePush(
      overlay,
      titre: message.titre ?? 'Notification',
      corps: message.corps ?? '',
      icone: iconeNotification(message.type),
      accent: couleurNotification(message.type),
      onTap: () => _pousserEcran(message),
    );
  }

  void _ouvrir(PushMessage message) {
    // Le compteur est périmé dès qu'une notification arrive.
    ref.invalidate(centreNotificationsProvider);
    _pousserEcran(message);
  }

  void _pousserEcran(PushMessage message) {
    widget.navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => _ecran(message)),
    );
  }

  /// Écran correspondant au type de notification.
  ///
  /// Le repli sur le centre de notifications n'est pas un pis-aller : une
  /// version installée depuis longtemps peut recevoir un type qu'elle ne
  /// connaît pas encore, et l'utilisateur doit malgré tout pouvoir lire ce
  /// qu'on lui a envoyé.
  Widget _ecran(PushMessage message) => switch (message.type) {
        'MAINTENANCE_A_VENIR' => const LignesMaintenancePage(),
        'RECETTE_ENCAISSEE' => const LignesRecettePage(),
        'COTISATION_ENCAISSEE' => const LignesCotisationPage(),
        _ => const NotificationsPage(),
      };

  @override
  Widget build(BuildContext context) {
    // Le centre appartient au compte connecté. À chaque entrée en session —
    // connexion comme déverrouillage — il se relit ; à chaque sortie il
    // s'efface, sans quoi le compte suivant ouvrirait la page sur les
    // notifications du précédent.
    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthAuthenticated || next is AuthUnauthenticated) {
        ref.invalidate(centreNotificationsProvider);
      }
      // Un bandeau affiché au moment où la session se referme survivrait à
      // l'écran de code et donnerait à lire ce que le code protège.
      if (next is! AuthAuthenticated) {
        masquerBannierePush();
      }
    });

    return widget.child;
  }
}
