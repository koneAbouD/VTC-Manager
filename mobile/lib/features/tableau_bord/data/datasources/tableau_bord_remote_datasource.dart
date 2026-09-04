import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/tableau_bord_model.dart';

class TableauBordRemoteDatasource {
  final ApiClient _client;
  const TableauBordRemoteDatasource(this._client);

  /// Photo complète de la période — quatre blocs en un appel, pour qu'ils
  /// parlent tous du même instant. Sans [annee]/[mois], le backend sert le
  /// mois courant.
  Future<TableauBordModel> getTableauBord({
    int? annee,
    int? mois,
    String base = 'CAISSE',
    int? groupeId,
    int? activiteId,
  }) async {
    final query = <String, String>{
      if (annee != null) 'annee': '$annee',
      if (mois != null) 'mois': '$mois',
      'base': base,
      if (groupeId != null) 'groupeId': '$groupeId',
      if (activiteId != null) 'activiteId': '$activiteId',
    };
    final data = await _client.get('/tableau-bord', query: query);
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return TableauBordModel.fromJson(data);
  }
}
