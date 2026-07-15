import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/ligne_recette_model.dart';

/// Accès distant aux recettes du chauffeur connecté (`GET /me/recettes`).
class RecetteRemoteDatasource {
  final ApiClient _client;
  const RecetteRemoteDatasource(this._client);

  Future<List<LigneRecetteModel>> getRecettes() async {
    final data = await _client.get('/me/recettes');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => LigneRecetteModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
