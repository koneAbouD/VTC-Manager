import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/page_result.dart';
import '../models/operation_financiere_model.dart';

class OperationFinanciereRemoteDatasource {
  final ApiClient _client;
  const OperationFinanciereRemoteDatasource(this._client);

  /// Liste paginée (scroll infini) via `GET /operations-financieres/page`.
  Future<PageResult<OperationFinanciereModel>> getPage({
    int page = 0,
    int size = 20,
    String? typeOperation,
    String? debut,
    String? fin,
    String? statut,
    String? categorieCode,
    String? sousCategorieLibelle,
    int? vehiculeId,
    int? chauffeurId,
    String? recherche,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (typeOperation != null) 'typeOperation': typeOperation,
      if (debut != null) 'debut': debut,
      if (fin != null) 'fin': fin,
      if (statut != null) 'statut': statut,
      if (categorieCode != null) 'categorieCode': categorieCode,
      if (sousCategorieLibelle != null)
        'sousCategorieLibelle': sousCategorieLibelle,
      if (vehiculeId != null) 'vehiculeId': '$vehiculeId',
      if (chauffeurId != null) 'chauffeurId': '$chauffeurId',
      if (recherche != null && recherche.isNotEmpty) 'recherche': recherche,
    };
    final data =
        await _client.get('/operations-financieres/page', query: query);
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return PageResult.fromJson(
      data,
      (e) => OperationFinanciereModel.fromJson(e),
    );
  }

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

  Future<void> annuler(int id) =>
      _client.patch('/operations-financieres/$id/annuler');
}
