import '../../../core/network/api_client.dart';

/// Une notification du centre de notifications.
class NotificationItem {
  final int id;

  /// Type métier (`PENALITE_APPLIQUEE`, `MAINTENANCE_A_VENIR`…). Il détermine
  /// l'icône et l'écran ouvert au toucher.
  final String type;

  final String titre;
  final String corps;

  /// Ce que le corps tait : chauffeur, véhicule, montants. Absent du message
  /// poussé — il ne s'affiche donc jamais sur l'écran verrouillé.
  final String? detail;

  /// Cible du lien, quand la notification en désigne une.
  final String? entiteType;
  final int? entiteId;

  final bool lue;
  final DateTime? creeLe;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.titre,
    required this.corps,
    required this.lue,
    this.detail,
    this.entiteType,
    this.entiteId,
    this.creeLe,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
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
}

/// Contenu du centre de notifications : la liste et le nombre de non-lues.
///
/// Les deux dans la même réponse parce que l'écran a besoin des deux en même
/// temps — la liste à afficher et le badge à poser.
class CentreNotifications {
  final List<NotificationItem> notifications;
  final int nonLues;

  const CentreNotifications({
    required this.notifications,
    required this.nonLues,
  });

  static const vide = CentreNotifications(notifications: [], nonLues: 0);

  factory CentreNotifications.fromJson(Map<String, dynamic> j) =>
      CentreNotifications(
        notifications: ((j['notifications'] as List<dynamic>?) ?? const [])
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        nonLues: j['nonLues'] as int? ?? 0,
      );
}

/// Accès REST au centre de notifications (endpoints `/api/notifications`).
///
/// Le destinataire n'est jamais transmis : le backend le déduit du jeton. On ne
/// peut donc lire que ses propres notifications.
class NotificationApi {
  final ApiClient _client;

  const NotificationApi(this._client);

  Future<CentreNotifications> centre() async {
    final res = await _client.get('/notifications');
    return CentreNotifications.fromJson(res as Map<String, dynamic>);
  }

  Future<void> marquerLue(int id) => _client.patch('/notifications/$id/lue');

  Future<void> marquerToutesLues() => _client.patch('/notifications/lues');

  /// Envoi de vérification vers ses propres appareils.
  Future<void> envoyerTest() => _client.post('/notifications/test', const {});
}
