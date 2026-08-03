import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/notification_item.dart';
import '../models/notification_model.dart';

/// Accès distant au centre de notifications du chauffeur
/// (`/me/notifications`).
///
/// Le destinataire n'est jamais transmis : le backend le déduit du jeton, comme
/// pour tout le scope `/me`.
class NotificationRemoteDatasource {
  final ApiClient _client;
  const NotificationRemoteDatasource(this._client);

  Future<CentreNotifications> getCentre() async {
    final data = await _client.get('/me/notifications');
    if (data is! Map) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return NotificationMapper.centreFromJson(data.cast<String, dynamic>());
  }

  Future<void> marquerLue(int id) =>
      _client.patch('/me/notifications/$id/lue');

  Future<void> marquerToutesLues() => _client.patch('/me/notifications/lues');
}
