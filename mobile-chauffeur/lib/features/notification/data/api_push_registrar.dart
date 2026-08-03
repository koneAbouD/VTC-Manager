import 'package:tmk_push/tmk_push.dart';

import '../../../core/network/api_client.dart';

/// Dépôt du jeton d'appareil pour l'espace chauffeur.
///
/// Les routes vivent sous `/api/me` : le backend rattache l'appareil au
/// chauffeur du jeton, jamais à un identifiant fourni par le client.
class ApiPushRegistrar implements PushRegistrar {
  final ApiClient _api;

  const ApiPushRegistrar(this._api);

  @override
  Future<void> enregistrer({
    required String token,
    required String plateforme,
  }) =>
      _api.post('/me/devices', {'token': token, 'plateforme': plateforme});

  @override
  Future<void> revoquer(String token) => _api.delete('/me/devices/$token');
}
