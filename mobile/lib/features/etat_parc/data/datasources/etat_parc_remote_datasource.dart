import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/etat_parc_summary_model.dart';

class EtatParcRemoteDatasource {
  final ApiClient _client;
  const EtatParcRemoteDatasource(this._client);

  /// Récupère la photo du parc, éventuellement restreinte à un [groupeId]
  /// et/ou un [activiteId] (filtrage réalisé côté backend).
  Future<EtatParcSummaryModel> getSummary({
    int? groupeId,
    int? activiteId,
  }) async {
    final query = <String, String>{
      if (groupeId != null) 'groupeId': '$groupeId',
      if (activiteId != null) 'activiteId': '$activiteId',
    };
    final data = await _client.get(
      '/etat-parc/summary',
      query: query.isEmpty ? null : query,
    );
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return EtatParcSummaryModel.fromJson(data);
  }
}
