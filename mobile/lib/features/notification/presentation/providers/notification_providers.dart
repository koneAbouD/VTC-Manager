import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/api_push_registrar.dart';
import '../../data/notification_api.dart';
import '../../data/reception_push.dart';

final notificationApiProvider = Provider<NotificationApi>(
  (ref) => NotificationApi(ref.watch(apiClientProvider)),
);

/// Commande de l'interrupteur « Notifications » des réglages.
final receptionPushProvider = Provider<ReceptionPush>(
  (ref) => ReceptionPush(
    ref.watch(secureStorageProvider),
    ApiPushRegistrar(ref.watch(apiClientProvider)),
  ),
);

/// Contenu du centre de notifications.
///
/// Volontairement sans `autoDispose` : le badge de l'écran de réglages s'y
/// abonne aussi, et la valeur doit survivre à la fermeture de la page pour ne
/// pas repartir en chargement à chaque aller-retour.
final centreNotificationsProvider =
    FutureProvider<CentreNotifications>((ref) async {
  return ref.watch(notificationApiProvider).centre();
});

/// Nombre de notifications non lues, pour le badge.
///
/// Rend 0 tant que la liste n'est pas chargée ou si elle a échoué : un badge
/// est un ornement, il n'a pas à afficher une erreur ni à faire patienter.
final nonLuesProvider = Provider<int>((ref) {
  return ref.watch(centreNotificationsProvider).maybeWhen(
        data: (centre) => centre.nonLues,
        orElse: () => 0,
      );
});
