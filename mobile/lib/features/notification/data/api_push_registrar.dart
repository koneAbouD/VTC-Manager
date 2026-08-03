import 'package:tmk_push/tmk_push.dart';

import '../../../core/network/api_client.dart';

/// Dépôt du jeton d'appareil pour l'application de gestion.
///
/// Le destinataire n'est jamais transmis : le backend le déduit du jeton
/// d'accès. Un compte ne peut donc pas enregistrer un appareil au nom d'un
/// autre.
class ApiPushRegistrar implements PushRegistrar {
  final ApiClient _api;

  const ApiPushRegistrar(this._api);

  @override
  Future<void> enregistrer({
    required String token,
    required String plateforme,
  }) =>
      _api.post('/devices', {'token': token, 'plateforme': plateforme});

  @override
  Future<void> revoquer(String token) => _api.delete('/devices/$token');
}
