import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/page_result.dart';
import '../models/indisponibilite_vehicule_model.dart';

/// Appels HTTP vers /api/indisponibilites-vehicule.
class IndisponibiliteVehiculeRemoteDatasource {
  final ApiClient _client;
  const IndisponibiliteVehiculeRemoteDatasource(this._client);

  /// Liste paginée (scroll infini) via `GET /indisponibilites-vehicule/page`.
  Future<PageResult<IndisponibiliteVehiculeModel>> getPage({
    int page = 0,
    int size = 20,
    int? vehiculeId,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (vehiculeId != null) 'vehiculeId': '$vehiculeId',
    };
    final data = await _client.get('/indisponibilites-vehicule/page', query: query);
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return PageResult.fromJson(
        data, (e) => IndisponibiliteVehiculeModel.fromJson(e));
  }

  Future<List<IndisponibiliteVehiculeModel>> getAll() async {
    final data = await _client.get('/indisponibilites-vehicule') as List;
    return data
        .map((e) =>
            IndisponibiliteVehiculeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<IndisponibiliteVehiculeModel> create(
      IndisponibiliteVehiculeModel m) async {
    final data = await _client.post('/indisponibilites-vehicule', m.toJson())
        as Map<String, dynamic>;
    return IndisponibiliteVehiculeModel.fromJson(data);
  }

  Future<IndisponibiliteVehiculeModel> update(
      int id, IndisponibiliteVehiculeModel m) async {
    final data = await _client.put('/indisponibilites-vehicule/$id', m.toJson())
        as Map<String, dynamic>;
    return IndisponibiliteVehiculeModel.fromJson(data);
  }

  Future<void> delete(int id) =>
      _client.delete('/indisponibilites-vehicule/$id');

  Future<IndisponibiliteVehiculeModel> terminer(int id) async {
    final data = await _client
        .post('/indisponibilites-vehicule/$id/terminer', {}) as Map<String, dynamic>;
    return IndisponibiliteVehiculeModel.fromJson(data);
  }
}
