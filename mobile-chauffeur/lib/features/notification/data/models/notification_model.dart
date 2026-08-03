import '../../domain/entities/notification_item.dart';

/// Lecture des notifications rendues par `/me/notifications`.
abstract final class NotificationMapper {
  static NotificationItem itemFromJson(Map<String, dynamic> j) =>
      NotificationItem(
        id: j['id'] as int,
        type: j['type'] as String? ?? '',
        titre: j['titre'] as String? ?? '',
        corps: j['corps'] as String? ?? '',
        detail: j['detail'] as String?,
        entiteType: j['entiteType'] as String?,
        entiteId: j['entiteId'] as int?,
        lue: j['lue'] as bool? ?? false,
        creeLe: j['creeLe'] == null
            ? null
            : DateTime.tryParse(j['creeLe'] as String),
      );

  static CentreNotifications centreFromJson(Map<String, dynamic> j) =>
      CentreNotifications(
        notifications: ((j['notifications'] as List<dynamic>?) ?? const [])
            .map((e) => itemFromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        nonLues: j['nonLues'] as int? ?? 0,
      );
}
