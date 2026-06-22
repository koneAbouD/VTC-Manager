import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/contravention_model.dart';

class ContraventionRemoteDatasource {
  final ApiClient _client;
  const ContraventionRemoteDatasource(this._client);

  Future<List<ContraventionModel>> getContraventions() async {
    final data = await _client.get('/contraventions');
    if (data is! List) throw ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => ContraventionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ContraventionModel> getContraventionById(int id) async {
    final data = await _client.get('/contraventions/$id');
    return ContraventionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ContraventionModel> createContravention(
      ContraventionModel contravention) async {
    final data = await _client.post('/contraventions', contravention.toJson());
    return ContraventionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ContraventionModel> updateContravention(
      int id, ContraventionModel contravention) async {
    final data =
        await _client.put('/contraventions/$id', contravention.toJson());
    return ContraventionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteContravention(int id) =>
      _client.delete('/contraventions/$id');

  Future<ContraventionModel> payContravention(
      int id, double montantPaye) async {
    final data = await _client
        .post('/contraventions/$id/payments', {'montantPaye': montantPaye});
    return ContraventionModel.fromJson(data as Map<String, dynamic>);
  }
}
