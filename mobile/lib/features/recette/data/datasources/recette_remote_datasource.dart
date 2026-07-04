import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/recette_model.dart';

class RecetteRemoteDatasource {
  final ApiClient _client;
  const RecetteRemoteDatasource(this._client);

  Future<List<RecetteModel>> getRecettes() async {
    final data = await _client.get('/recettes');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => RecetteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RecetteModel> getRecetteById(int id) async {
    final data = await _client.get('/recettes/$id');
    return RecetteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<RecetteModel> createRecette(RecetteModel recette) async {
    final data = await _client.post('/recettes', recette.toJson());
    return RecetteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<RecetteModel> updateRecette(int id, RecetteModel recette) async {
    final data = await _client.put('/recettes/$id', recette.toJson());
    return RecetteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteRecette(int id) => _client.delete('/recettes/$id');
}
