import '../../../../core/network/api_client.dart';
import '../models/paiement_model.dart';

/// Accès distant aux paiements Mobile Money (`/me/paiements`).
class PaiementRemoteDatasource {
  final ApiClient _client;
  const PaiementRemoteDatasource(this._client);

  Future<PaiementModel> initier({
    required String typeCible,
    required int cibleId,
    required String canal,
    required String telephone,
  }) async {
    final data = await _client.post('/me/paiements', {
      'typeCible': typeCible,
      'cibleId': cibleId,
      'canal': canal,
      'telephone': telephone,
    });
    return PaiementModel.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<PaiementModel> statut(String reference) async {
    final data = await _client.get('/me/paiements/$reference');
    return PaiementModel.fromJson((data as Map).cast<String, dynamic>());
  }
}
