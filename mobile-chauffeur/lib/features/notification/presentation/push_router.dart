import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_push/tmk_push.dart';

import '../../auth/presentation/providers/auth_controller.dart';
import '../../auth/presentation/providers/auth_state.dart';
import '../../contravention/presentation/pages/infractions_page.dart';
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

class _PushRouterState extends ConsumerState<PushRouter> {
  StreamSubscription<PushMessage>? _liens;
  StreamSubscription<PushMessage>? _premierPlan;

  @override
  void initState() {
    super.initState();
    _liens = PushService.instance.liens.listen(_ouvrir);
    _premierPlan = PushService.instance.messagesAuPremierPlan.listen(_annoncer);
  }

  @override
  void dispose() {
    _liens?.cancel();
    _premierPlan?.cancel();
    super.dispose();
  }

  /// Notification reçue application ouverte.
  ///
  /// Android n'affiche rien de lui-même dans ce cas : sans ce bandeau, un
  /// chauffeur qui consulte son compte au moment où son versement est
  /// enregistré ne verrait rien passer.
  void _annoncer(PushMessage message) {
    // Le compteur de non-lues vient de changer, quoi qu'on affiche.
    ref.invalidate(centreNotificationsProvider);

    // Sous clé, l'écran de code est affiché : le texte de la notification n'a
    // rien à faire par-dessus, c'est précisément ce dont le code protège.
    if (ref.read(authControllerProvider) is! AuthAuthenticated) return;

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
  /// connaît pas encore, et le chauffeur doit malgré tout pouvoir lire ce qu'on
  /// lui a envoyé.
  Widget _ecran(PushMessage message) => switch (message.type) {
        'PENALITE_APPLIQUEE' => const InfractionsPage(),
        _ => const NotificationsPage(),
      };

  @override
  Widget build(BuildContext context) {
    // Un bandeau affiché au moment où la session se referme survivrait à
    // l'écran de code et donnerait à lire ce que le code protège.
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next is! AuthAuthenticated) masquerBannierePush();
    });

    return widget.child;
  }
}
