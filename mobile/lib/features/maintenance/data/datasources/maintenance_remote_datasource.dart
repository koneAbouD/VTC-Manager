import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/maintenance_model.dart';

class MaintenanceRemoteDatasource {
  final ApiClient _client;
  const MaintenanceRemoteDatasource(this._client);

  Future<List<MaintenanceModel>> getMaintenances({
    String? dateDebut,
    String? dateFin,
    String? statut,
    int? vehiculeId,
  }) async {
    final params = <String, String>{};
    if (dateDebut != null) params['dateDebut'] = dateDebut;
    if (dateFin != null) params['dateFin'] = dateFin;
    if (statut != null) params['statut'] = statut;
    if (vehiculeId != null) params['vehiculeId'] = '$vehiculeId';

    final uri = params.isEmpty
        ? '/maintenances'
        : '/maintenances?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';

    final data = await _client.get(uri);
    if (data is! List) throw ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => MaintenanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MaintenanceModel> getMaintenanceById(int id) async {
    final data = await _client.get('/maintenances/$id');
    return MaintenanceModel.fromJson(data as Map<String, dynamic>);
  }

  Future<MaintenanceModel> createMaintenance(MaintenanceModel maintenance) async {
    final data = await _client.post('/maintenances', maintenance.toJson());
    return MaintenanceModel.fromJson(data as Map<String, dynamic>);
  }

  Future<MaintenanceModel> updateMaintenance(int id, MaintenanceModel maintenance) async {
    final data = await _client.put('/maintenances/$id', maintenance.toJson());
    return MaintenanceModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteMaintenance(int id) => _client.delete('/maintenances/$id');

  Future<MaintenanceModel> completeMaintenance(int id, double cout) async {
    final data = await _client.post('/maintenances/$id/complete', {'cout': cout});
    return MaintenanceModel.fromJson(data as Map<String, dynamic>);
  }
}
