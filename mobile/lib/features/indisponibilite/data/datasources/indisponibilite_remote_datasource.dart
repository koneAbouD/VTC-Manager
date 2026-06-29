import '../../../../core/network/api_client.dart';
import '../models/indisponibilite_model.dart';

/// Appels HTTP vers /api/indisponibilites.
class IndisponibiliteRemoteDatasource {
  final ApiClient _client;
  const IndisponibiliteRemoteDatasource(this._client);

  Future<List<IndisponibiliteModel>> getIndisponibilites() async {
    final data = await _client.get('/indisponibilites') as List;
    return data
        .map((e) =>
            IndisponibiliteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<IndisponibiliteModel> create(IndisponibiliteModel m) async {
    final data =
        await _client.post('/indisponibilites', m.toJson()) as Map<String, dynamic>;
    return IndisponibiliteModel.fromJson(data);
  }

  Future<IndisponibiliteModel> update(int id, IndisponibiliteModel m) async {
    final data = await _client.put('/indisponibilites/$id', m.toJson())
        as Map<String, dynamic>;
    return IndisponibiliteModel.fromJson(data);
  }

  Future<void> delete(int id) => _client.delete('/indisponibilites/$id');

  Future<IndisponibiliteModel> terminer(int id) async {
    final data = await _client.post('/indisponibilites/$id/terminer', {})
        as Map<String, dynamic>;
    return IndisponibiliteModel.fromJson(data);
  }
}
