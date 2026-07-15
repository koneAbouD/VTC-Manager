import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/contravention_model.dart';

/// Accès distant aux contraventions du chauffeur (`GET /me/contraventions`).
class ContraventionRemoteDatasource {
  final ApiClient _client;
  const ContraventionRemoteDatasource(this._client);

  Future<List<ContraventionModel>> getContraventions() async {
    final data = await _client.get('/me/contraventions');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => ContraventionModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
