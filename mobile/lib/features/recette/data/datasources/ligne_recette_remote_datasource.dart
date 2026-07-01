import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/page_result.dart';
import '../models/encaissement_model.dart';
import '../models/ligne_recette_model.dart';

class LigneRecetteRemoteDatasource {
  final ApiClient _client;
  const LigneRecetteRemoteDatasource(this._client);

  /// Liste paginée (scroll infini) via `GET /recettes/lignes/page`.
  Future<PageResult<LigneRecetteModel>> getLignesPage({
    int page = 0,
    int size = 20,
    int? vehiculeId,
    int? chauffeurId,
    String? statut,
    String? dateDebut,
    String? dateFin,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (vehiculeId != null) 'vehiculeId': '$vehiculeId',
      if (chauffeurId != null) 'chauffeurId': '$chauffeurId',
      if (statut != null) 'statut': statut,
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
    };
    final data = await _client.get('/recettes/lignes/page', query: query);
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return PageResult.fromJson(data, (e) => LigneRecetteModel.fromJson(e));
  }

  Future<List<LigneRecetteModel>> getLignes({
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
    final data = await _client.get('/recettes/lignes', query: query.isEmpty ? null : query);
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data.map((e) => LigneRecetteModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LigneRecetteModel> getLigneById(int id) async {
    final data = await _client.get('/recettes/lignes/$id');
    return LigneRecetteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<EncaissementModel> createEncaissement(int ligneId, EncaissementModel encaissement) async {
    final data = await _client.post('/recettes/lignes/$ligneId/encaissements', encaissement.toJson());
    return EncaissementModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LigneRecetteModel> annuler(int id) async {
    final data = await _client.patch('/recettes/lignes/$id/annuler');
    return LigneRecetteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LigneRecetteModel> confirmerVersement(int id) async {
    final data = await _client.patch('/recettes/lignes/$id/confirmer-versement');
    return LigneRecetteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<LigneRecetteModel>> generer({String? date}) async {
    final query = date != null ? {'date': date} : null;
    final data = await _client.post('/recettes/lignes/generer', <String, dynamic>{}, query: query);
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data.map((e) => LigneRecetteModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
