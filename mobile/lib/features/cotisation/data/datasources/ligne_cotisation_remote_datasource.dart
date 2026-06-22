import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/encaissement_cotisation_model.dart';
import '../models/ligne_cotisation_model.dart';

class LigneCotisationRemoteDatasource {
  final ApiClient _client;
  const LigneCotisationRemoteDatasource(this._client);

  Future<List<LigneCotisationModel>> getLignes({
    int? vehiculeId,
    int? chauffeurId,
    String? statut,
    String? dateDebut,
    String? dateFin,
  }) async {
    final query = <String, String>{
      if (vehiculeId != null) 'vehiculeId': '$vehiculeId',
      if (chauffeurId != null) 'chauffeurId': '$chauffeurId',
      if (statut != null) 'statut': statut,
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
    };
    final data = await _client.get('/cotisations/lignes', query: query.isEmpty ? null : query);
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data.map((e) => LigneCotisationModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LigneCotisationModel> getLigneById(int id) async {
    final data = await _client.get('/cotisations/lignes/$id');
    return LigneCotisationModel.fromJson(data as Map<String, dynamic>);
  }

  Future<EncaissementCotisationModel> createEncaissement(
      int ligneId, EncaissementCotisationModel enc) async {
    final data = await _client.post('/cotisations/lignes/$ligneId/encaissements', enc.toJson());
    return EncaissementCotisationModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LigneCotisationModel> annuler(int id) async {
    final data = await _client.patch('/cotisations/lignes/$id/annuler');
    return LigneCotisationModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<LigneCotisationModel>> generer({String? date}) async {
    final query = date != null ? {'date': date} : null;
    final data = await _client.post('/cotisations/lignes/generer', <String, dynamic>{}, query: query);
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data.map((e) => LigneCotisationModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
