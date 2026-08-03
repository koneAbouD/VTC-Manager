import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/repositories_impl/notification_repository_impl.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/get_notifications_usecase.dart';

final _notificationDatasourceProvider = Provider<NotificationRemoteDatasource>(
  (ref) => NotificationRemoteDatasource(ref.watch(apiClientProvider)),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(ref.watch(_notificationDatasourceProvider)),
);

final getNotificationsUseCaseProvider = Provider<GetNotificationsUseCase>(
  (ref) => GetNotificationsUseCase(ref.watch(notificationRepositoryProvider)),
);

final marquerNotificationLueUseCaseProvider =
    Provider<MarquerNotificationLueUseCase>(
  (ref) =>
      MarquerNotificationLueUseCase(ref.watch(notificationRepositoryProvider)),
);

/// Contenu du centre de notifications.
///
/// Volontairement sans `autoDispose` : le badge de l'accueil s'y abonne aussi,
/// et la valeur doit survivre à la fermeture de la page pour ne pas repartir en
/// chargement à chaque aller-retour.
final centreNotificationsProvider =
    FutureProvider<CentreNotifications>((ref) async {
  final result = await ref.watch(getNotificationsUseCaseProvider).call();
  return result.fold((f) => throw f.message, (r) => r);
});

/// Nombre de non-lues, pour la pastille de l'accueil.
///
/// Rend 0 tant que la liste n'est pas chargée ou si elle a échoué : une
/// pastille est un ornement, elle n'a pas à afficher une erreur.
final nonLuesProvider = Provider<int>((ref) {
  return ref.watch(centreNotificationsProvider).maybeWhen(
        data: (centre) => centre.nonLues,
        orElse: () => 0,
      );
});
