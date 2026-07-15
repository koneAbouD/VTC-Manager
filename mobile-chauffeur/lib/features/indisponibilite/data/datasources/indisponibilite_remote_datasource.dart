import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/indisponibilite_model.dart';
import '../models/remplacant_model.dart';

/// Accès distant aux indisponibilités du chauffeur connecté (`/api/me`).
class IndisponibiliteRemoteDatasource {
  final ApiClient _client;
  const IndisponibiliteRemoteDatasource(this._client);

  Future<List<IndisponibiliteModel>> getIndisponibilites() async {
    final data = await _client.get('/me/indisponibilites');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => IndisponibiliteModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<RemplacantModel>> getRemplacants() async {
    final data = await _client.get('/me/remplacants');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => RemplacantModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<IndisponibiliteModel> declarer({
    required int chauffeurRemplacantId,
    required String dateDebut,
    String? dateFin,
    String? motif,
    String? commentaire,
  }) async {
    final data = await _client.post('/me/indisponibilites', {
      'chauffeurRemplacantId': chauffeurRemplacantId,
      'dateDebut': dateDebut,
      'dateFin': ?dateFin,
      'motif': ?motif,
      'commentaire': ?commentaire,
    });
    return IndisponibiliteModel.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<IndisponibiliteModel> terminer(int id) async {
    final data = await _client.post('/me/indisponibilites/$id/terminer');
    return IndisponibiliteModel.fromJson((data as Map).cast<String, dynamic>());
  }
}
