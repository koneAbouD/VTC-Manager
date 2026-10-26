import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/operation_financiere_model.dart';

/// Accès distant aux opérations du chauffeur / véhicule (`GET /me/operations`).
class OperationRemoteDatasource {
  final ApiClient _client;
  const OperationRemoteDatasource(this._client);

  Future<List<OperationFinanciereModel>> getOperations() async {
    final data = await _client.get('/me/operations');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) =>
            OperationFinanciereModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
