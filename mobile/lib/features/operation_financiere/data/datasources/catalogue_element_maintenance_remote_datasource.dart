import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/catalogue_element_maintenance_model.dart';

class CatalogueElementMaintenanceRemoteDatasource {
  final ApiClient _client;
  const CatalogueElementMaintenanceRemoteDatasource(this._client);

  /// Éléments **actifs** uniquement (sélection lors de la saisie d'une
  /// maintenance). Le paramétrage, lui, liste tout via le module générique.
  /// Avec [vehiculeId], seuls les éléments compatibles avec la marque et le
  /// modèle du véhicule sont renvoyés ; avec [categorieTypeIds], seuls les
  /// éléments communs ou réservés à l'un de ces types de maintenance.
  Future<List<CatalogueElementMaintenanceModel>> getAll(
      {int? vehiculeId, List<int> categorieTypeIds = const []}) async {
    final data = await _client.get('/catalogue-elements-maintenance/actifs',
        query: {
          if (vehiculeId != null) 'vehiculeId': '$vehiculeId',
          if (categorieTypeIds.isNotEmpty)
            'categorieTypeIds': categorieTypeIds.join(','),
        });
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => CatalogueElementMaintenanceModel.fromJson(
            e as Map<String, dynamic>))
        .toList();
  }
}
