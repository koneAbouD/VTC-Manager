import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/page_result.dart';
import '../models/encaissement_model.dart';
import '../models/ligne_recette_model.dart';
import '../../../../core/models/apercu_reaffectation.dart';
import '../../../../core/models/encaissement_lot.dart';

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
    String? recherche,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (vehiculeId != null) 'vehiculeId': '$vehiculeId',
      if (chauffeurId != null) 'chauffeurId': '$chauffeurId',
      if (statut != null) 'statut': statut,
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
      if (recherche != null && recherche.trim().isNotEmpty)
        'recherche': recherche.trim(),
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

  /// Encaissement de masse : un seul aller-retour pour tout le lot. Le serveur
  /// répond toujours 200 et rend son verdict ligne par ligne.
  Future<ResultatEncaissementLot> createEncaissementsLot({
    required List<MontantLigne> lignes,
    required String modeEncaissement,
    required DateTime dateEncaissement,
    String? reference,
    String? commentaire,
  }) async {
    final data = await _client.post('/recettes/lignes/encaissements-lot', {
      'lignes': lignes.map((l) => l.toJson()).toList(),
      'modeEncaissement': modeEncaissement,
      'dateEncaissement': dateEncaissement.toIso8601String().substring(0, 10),
      if (reference != null) 'reference': reference,
      if (commentaire != null) 'commentaire': commentaire,
    });
    return ResultatEncaissementLot.fromJson(data as Map<String, dynamic>);
  }

  Future<LigneRecetteModel> annuler(int id, String motif) async {
    final data = await _client.patch('/recettes/lignes/$id/annuler', {'motif': motif});
    return LigneRecetteModel.fromJson(data as Map<String, dynamic>);
  }

  /// Qui peut reprendre la ligne, et ce que le déplacement entraînera. Le
  /// serveur juge chaque chauffeur : l'écran n'a rien à recalculer.
  Future<ApercuReaffectation> getApercuReaffectation(int id) async {
    final data = await _client.get('/recettes/lignes/$id/chauffeurs-eligibles');
    return ApercuReaffectation.fromJson(data as Map<String, dynamic>);
  }

  /// Porte la ligne au compte d'un autre chauffeur. Le motif est obligatoire :
  /// le serveur refuse une réaffectation qui ne s'explique pas.
  Future<LigneRecetteModel> reaffecterChauffeur(int id, int chauffeurId, String motif) async {
    final data = await _client.patch('/recettes/lignes/$id/chauffeur', {
      'chauffeurId': chauffeurId,
      'motif': motif,
    });
    return LigneRecetteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LigneRecetteModel> restaurer(int id) async {
    final data = await _client.patch('/recettes/lignes/$id/restaurer');
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
