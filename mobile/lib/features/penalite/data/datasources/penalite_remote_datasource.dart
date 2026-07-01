import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/page_result.dart';
import '../models/encaissement_penalite_model.dart';
import '../models/ligne_penalite_model.dart';

class PenaliteRemoteDatasource {
  final ApiClient _client;
  const PenaliteRemoteDatasource(this._client);

  /// Liste paginée (scroll infini) via `GET /penalites/lignes/page`.
  Future<PageResult<LignePenaliteModel>> getLignesPage({
    int page = 0,
    int size = 20,
    int? vehiculeId,
    int? chauffeurId,
    String? typeSanction,
    String? statut,
    String? dateDebut,
    String? dateFin,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (vehiculeId != null) 'vehiculeId': '$vehiculeId',
      if (chauffeurId != null) 'chauffeurId': '$chauffeurId',
      if (typeSanction != null) 'typeSanction': typeSanction,
      if (statut != null) 'statut': statut,
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
    };
    final data = await _client.get('/penalites/lignes/page', query: query);
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return PageResult.fromJson(data, (e) => LignePenaliteModel.fromJson(e));
  }

  Future<List<LignePenaliteModel>> getLignes({
    int? vehiculeId,
    int? chauffeurId,
    String? typeSanction,
    String? statut,
    String? dateDebut,
    String? dateFin,
  }) async {
    final query = <String, String>{
      if (vehiculeId != null) 'vehiculeId': '$vehiculeId',
      if (chauffeurId != null) 'chauffeurId': '$chauffeurId',
      if (typeSanction != null) 'typeSanction': typeSanction,
      if (statut != null) 'statut': statut,
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
    };
    final data = await _client.get('/penalites/lignes',
        query: query.isEmpty ? null : query);
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => LignePenaliteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LignePenaliteModel> getLigneById(int id) async {
    final data = await _client.get('/penalites/lignes/$id');
    return LignePenaliteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LignePenaliteModel> createLigne(Map<String, dynamic> body) async {
    final data = await _client.post('/penalites/lignes', body);
    return LignePenaliteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LignePenaliteModel> signalerRetard(Map<String, dynamic> body) async {
    final data = await _client.post('/penalites/lignes/signaler-retard', body);
    return LignePenaliteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<EncaissementPenaliteModel> createEncaissement(
      int ligneId, EncaissementPenaliteModel encaissement) async {
    final data = await _client.post(
        '/penalites/lignes/$ligneId/encaissements', encaissement.toJson());
    return EncaissementPenaliteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<EncaissementPenaliteModel>> getEncaissements(int ligneId) async {
    final data = await _client.get('/penalites/lignes/$ligneId/encaissements');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => EncaissementPenaliteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LignePenaliteModel> executer(int id) async {
    final data = await _client.patch('/penalites/lignes/$id/executer');
    return LignePenaliteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LignePenaliteModel> notifier(int id) async {
    final data = await _client.patch('/penalites/lignes/$id/notifier');
    return LignePenaliteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LignePenaliteModel> demarrer(int id) async {
    final data = await _client.patch('/penalites/lignes/$id/demarrer');
    return LignePenaliteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LignePenaliteModel> lever(int id) async {
    final data = await _client.patch('/penalites/lignes/$id/lever');
    return LignePenaliteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LignePenaliteModel> annuler(int id) async {
    final data = await _client.patch('/penalites/lignes/$id/annuler');
    return LignePenaliteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<LignePenaliteModel>> generer({String? date}) async {
    final query = date != null ? {'date': date} : null;
    final data = await _client.post(
        '/penalites/lignes/generer', <String, dynamic>{}, query: query);
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => LignePenaliteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
