import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/page_result.dart';
import '../models/encaissement_cotisation_model.dart';
import '../models/ligne_cotisation_model.dart';

class LigneCotisationRemoteDatasource {
  final ApiClient _client;
  const LigneCotisationRemoteDatasource(this._client);

  /// Liste paginée (scroll infini) via `GET /cotisations/lignes/page`.
  Future<PageResult<LigneCotisationModel>> getLignesPage({
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
    final data = await _client.get('/cotisations/lignes/page', query: query);
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return PageResult.fromJson(data, (e) => LigneCotisationModel.fromJson(e));
  }

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

  Future<LigneCotisationModel> annuler(int id, String motif) async {
    final data = await _client.patch('/cotisations/lignes/$id/annuler', {'motif': motif});
    return LigneCotisationModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<LigneCotisationModel>> generer({String? date}) async {
    final query = date != null ? {'date': date} : null;
    final data = await _client.post('/cotisations/lignes/generer', <String, dynamic>{}, query: query);
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data.map((e) => LigneCotisationModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
