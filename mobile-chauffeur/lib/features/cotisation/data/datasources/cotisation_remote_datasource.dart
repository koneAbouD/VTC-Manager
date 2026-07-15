import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/ligne_cotisation_model.dart';

/// Accès distant aux cotisations du chauffeur connecté (`GET /me/cotisations`).
class CotisationRemoteDatasource {
  final ApiClient _client;
  const CotisationRemoteDatasource(this._client);

  Future<List<LigneCotisationModel>> getCotisations() async {
    final data = await _client.get('/me/cotisations');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => LigneCotisationModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
