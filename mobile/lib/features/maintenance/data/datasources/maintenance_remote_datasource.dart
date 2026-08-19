import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/page_result.dart';
import '../models/maintenance_model.dart';

class MaintenanceRemoteDatasource {
  final ApiClient _client;
  const MaintenanceRemoteDatasource(this._client);

  /// Liste paginée (scroll infini) via `GET /maintenances/page`.
  Future<PageResult<MaintenanceModel>> getMaintenancesPage({
    int page = 0,
    int size = 20,
    String? dateDebut,
    String? dateFin,
    String? statut,
    int? vehiculeId,
    String? recherche,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
      if (statut != null) 'statut': statut,
      if (vehiculeId != null) 'vehiculeId': '$vehiculeId',
      if (recherche != null && recherche.trim().isNotEmpty)
        'recherche': recherche.trim(),
    };
    final data = await _client.get('/maintenances/page', query: query);
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return PageResult.fromJson(data, (e) => MaintenanceModel.fromJson(e));
  }

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
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
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

  /// Annule l'intervention : le motif est obligatoire, le serveur refuse sans.
  Future<MaintenanceModel> annulerMaintenance(int id, String motif) async {
    final data = await _client.patch('/maintenances/$id/annuler', {'motif': motif});
    return MaintenanceModel.fromJson(data as Map<String, dynamic>);
  }

  /// Remet une maintenance annulée en circulation : elle repasse en planifiée.
  /// Refusé par le serveur si la période est clôturée.
  Future<MaintenanceModel> restaurerMaintenance(int id) async {
    final data = await _client.patch('/maintenances/$id/restaurer');
    return MaintenanceModel.fromJson(data as Map<String, dynamic>);
  }

  /// Clôture l'intervention. [aCredit] la laisse due : le backend crée alors
  /// une dette par prestataire au lieu d'une dépense payée.
  Future<MaintenanceModel> completeMaintenance(
    int id,
    double cout, {
    bool aCredit = false,
    DateTime? dateEcheance,
  }) async {
    final data = await _client.post('/maintenances/$id/complete', {
      'cout': cout,
      if (aCredit) 'aCredit': true,
      if (aCredit && dateEcheance != null)
        'dateEcheance': dateEcheance.toIso8601String().split('T').first,
    });
    return MaintenanceModel.fromJson(data as Map<String, dynamic>);
  }
}
