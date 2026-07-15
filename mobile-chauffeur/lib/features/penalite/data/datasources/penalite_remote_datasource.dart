import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/ligne_penalite_model.dart';

/// Accès distant aux pénalités (amendes) du chauffeur (`GET /me/penalites`).
class PenaliteRemoteDatasource {
  final ApiClient _client;
  const PenaliteRemoteDatasource(this._client);

  Future<List<LignePenaliteModel>> getPenalites() async {
    final data = await _client.get('/me/penalites');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => LignePenaliteModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
