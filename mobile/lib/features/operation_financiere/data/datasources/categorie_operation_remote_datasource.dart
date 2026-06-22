import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/categorie_operation_model.dart';
import '../models/sous_categorie_operation_model.dart';

class CategorieOperationRemoteDatasource {
  final ApiClient _client;
  const CategorieOperationRemoteDatasource(this._client);

  Future<List<CategorieOperationModel>> getAll(
      {String? typeOperation, bool includeSousCategorie = false}) async {
    final query = <String, String>{
      if (typeOperation != null) 'typeOperation': typeOperation,
      if (includeSousCategorie) 'includeSousCategorie': 'true',
    };
    final data =
        await _client.get('/categories-operation', query: query);
    if (data is! List) throw ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) =>
            CategorieOperationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SousCategorieOperationModel>> getSousCategories(
      {required int categorieId}) async {
    final data = await _client.get('/sous-categories-operation',
        query: {'categorieId': '$categorieId'});
    if (data is! List) throw ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => SousCategorieOperationModel.fromJson(
            e as Map<String, dynamic>))
        .toList();
  }
}
