import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/depense_model.dart';

class DepenseRemoteDatasource {
  final ApiClient _client;
  const DepenseRemoteDatasource(this._client);

  Future<List<DepenseModel>> getDepenses() async {
    final data = await _client.get('/depenses');
    if (data is! List) throw ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => DepenseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DepenseModel> getDepenseById(int id) async {
    final data = await _client.get('/depenses/$id');
    return DepenseModel.fromJson(data as Map<String, dynamic>);
  }

  Future<DepenseModel> createDepense(DepenseModel depense) async {
    final data = await _client.post('/depenses', depense.toJson());
    return DepenseModel.fromJson(data as Map<String, dynamic>);
  }

  Future<DepenseModel> updateDepense(int id, DepenseModel depense) async {
    final data = await _client.put('/depenses/$id', depense.toJson());
    return DepenseModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteDepense(int id) => _client.delete('/depenses/$id');
}
