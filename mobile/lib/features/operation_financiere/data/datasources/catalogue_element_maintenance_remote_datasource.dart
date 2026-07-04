import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/catalogue_element_maintenance_model.dart';

class CatalogueElementMaintenanceRemoteDatasource {
  final ApiClient _client;
  const CatalogueElementMaintenanceRemoteDatasource(this._client);

  Future<List<CatalogueElementMaintenanceModel>> getAll() async {
    final data = await _client.get('/catalogue-elements-maintenance');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => CatalogueElementMaintenanceModel.fromJson(
            e as Map<String, dynamic>))
        .toList();
  }
}
