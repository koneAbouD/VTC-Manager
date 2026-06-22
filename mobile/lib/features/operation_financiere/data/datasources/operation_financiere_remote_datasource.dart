import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/operation_financiere_model.dart';

class OperationFinanciereRemoteDatasource {
  final ApiClient _client;
  const OperationFinanciereRemoteDatasource(this._client);

  Future<List<OperationFinanciereModel>> getAll({
    String? typeOperation,
    String? debut,
    String? fin,
    String? statut,
    String? categorieCode,
  }) async {
    final query = <String, String>{
      if (typeOperation != null) 'typeOperation': typeOperation,
      if (debut != null) 'debut': debut,
      if (fin != null) 'fin': fin,
      if (statut != null) 'statut': statut,
      if (categorieCode != null) 'categorieCode': categorieCode,
    };
    final data = await _client.get('/operations-financieres', query: query);
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) =>
            OperationFinanciereModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OperationFinanciereModel> getById(int id) async {
    final data = await _client.get('/operations-financieres/$id');
    return OperationFinanciereModel.fromJson(data as Map<String, dynamic>);
  }

  Future<OperationFinanciereModel> create(
      Map<String, dynamic> payload) async {
    final data = await _client.post('/operations-financieres', payload);
    return OperationFinanciereModel.fromJson(data as Map<String, dynamic>);
  }

  Future<OperationFinanciereModel> update(
      int id, Map<String, dynamic> payload) async {
    final data =
        await _client.put('/operations-financieres/$id', payload);
    return OperationFinanciereModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(int id) =>
      _client.delete('/operations-financieres/$id');

  Future<void> valider(int id) =>
      _client.patch('/operations-financieres/$id/valider');

  Future<void> annuler(int id) =>
      _client.patch('/operations-financieres/$id/annuler');
}
