import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/page_result.dart';
import '../models/encaissement_cotisation_model.dart';
import '../models/ligne_cotisation_model.dart';
import '../../domain/entities/totaux_cotisation.dart';
import '../../../../core/models/apercu_reaffectation.dart';
import '../../../../core/models/encaissement_lot.dart';

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

  /// Cumuls de la sélection via `GET /cotisations/lignes/totaux`.
  ///
  /// Le statut n'est pas transmis : ces montants servent à choisir un statut,
  /// et filtrer dessus mettrait toutes les autres pastilles à zéro.
  Future<TotauxCotisation> getTotaux({
    int? vehiculeId,
    int? chauffeurId,
    String? dateDebut,
    String? dateFin,
    String? recherche,
  }) async {
    final query = <String, String>{
      if (vehiculeId != null) 'vehiculeId': '$vehiculeId',
      if (chauffeurId != null) 'chauffeurId': '$chauffeurId',
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
      if (recherche != null && recherche.trim().isNotEmpty)
        'recherche': recherche.trim(),
    };
    final data = await _client.get('/cotisations/lignes/totaux',
        query: query.isEmpty ? null : query);
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return TotauxCotisation.fromJson(data);
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

  /// Encaissement de masse : un seul aller-retour pour tout le lot. Le serveur
  /// répond toujours 200 et rend son verdict ligne par ligne.
  Future<ResultatEncaissementLot> createEncaissementsLot({
    required List<MontantLigne> lignes,
    required String modeEncaissement,
    required DateTime dateEncaissement,
    String? reference,
    String? commentaire,
  }) async {
    final data = await _client.post('/cotisations/lignes/encaissements-lot', {
      'lignes': lignes.map((l) => l.toJson()).toList(),
      'modeEncaissement': modeEncaissement,
      'dateEncaissement': dateEncaissement.toIso8601String().substring(0, 10),
      if (reference != null) 'reference': reference,
      if (commentaire != null) 'commentaire': commentaire,
    });
    return ResultatEncaissementLot.fromJson(data as Map<String, dynamic>);
  }

  Future<LigneCotisationModel> annuler(int id, String motif) async {
    final data = await _client.patch('/cotisations/lignes/$id/annuler', {'motif': motif});
    return LigneCotisationModel.fromJson(data as Map<String, dynamic>);
  }

  /// Qui peut reprendre la ligne, et ce que le déplacement entraînera. Le
  /// serveur juge chaque chauffeur : l'écran n'a rien à recalculer.
  Future<ApercuReaffectation> getApercuReaffectation(int id) async {
    final data = await _client.get('/cotisations/lignes/$id/chauffeurs-eligibles');
    return ApercuReaffectation.fromJson(data as Map<String, dynamic>);
  }

  /// Porte la ligne au compte d'un autre chauffeur. Le motif est obligatoire :
  /// le serveur refuse une réaffectation qui ne s'explique pas.
  Future<LigneCotisationModel> reaffecterChauffeur(int id, int chauffeurId, String motif) async {
    final data = await _client.patch('/cotisations/lignes/$id/chauffeur', {
      'chauffeurId': chauffeurId,
      'motif': motif,
    });
    return LigneCotisationModel.fromJson(data as Map<String, dynamic>);
  }

  /// Corrige le jour d'un versement déjà enregistré. Le serveur déplace
  /// l'encaissement et l'écriture qu'il a produite, puis renvoie la ligne à
  /// jour — drapeaux compris.
  Future<LigneCotisationModel> modifierDateEncaissement(
      int ligneId, int encaissementId, DateTime date) async {
    final data = await _client.patch(
      '/cotisations/lignes/$ligneId/encaissements/$encaissementId/date',
      {'dateEncaissement': date.toIso8601String().substring(0, 10)},
    );
    return LigneCotisationModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LigneCotisationModel> restaurer(int id) async {
    final data = await _client.patch('/cotisations/lignes/$id/restaurer');
    return LigneCotisationModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<LigneCotisationModel>> generer({String? date}) async {
    final query = date != null ? {'date': date} : null;
    final data = await _client.post('/cotisations/lignes/generer', <String, dynamic>{}, query: query);
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data.map((e) => LigneCotisationModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
