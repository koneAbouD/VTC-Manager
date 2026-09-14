import '../../../../core/network/api_client.dart';
import '../../domain/entities/encaissement_versement.dart';
import '../../domain/entities/versement.dart';

class VersementRemoteDatasource {
  final ApiClient _client;
  const VersementRemoteDatasource(this._client);

  static String _jour(DateTime date) =>
      date.toIso8601String().substring(0, 10);

  Future<VersementEnregistre> encaisser({
    PartVersement? recette,
    PartVersement? cotisation,
    required String modeEncaissement,
    required DateTime dateEncaissement,
    String? reference,
    String? commentaire,
  }) async {
    final data = await _client.post('/versements', {
      if (recette != null) 'recette': recette.toJson(),
      if (cotisation != null) 'cotisation': cotisation.toJson(),
      'modeEncaissement': modeEncaissement,
      'dateEncaissement': _jour(dateEncaissement),
      if (reference != null) 'reference': reference,
      if (commentaire != null) 'commentaire': commentaire,
    });
    return VersementEnregistre.fromJson(data as Map<String, dynamic>);
  }

  Future<ResultatVersementLot> encaisserLot({
    required List<ElementVersementLot> versements,
    required String modeEncaissement,
    required DateTime dateEncaissement,
    String? reference,
    String? commentaire,
  }) async {
    final data = await _client.post('/versements/lot', {
      'versements': versements.map((v) => v.toJson()).toList(),
      'modeEncaissement': modeEncaissement,
      'dateEncaissement': _jour(dateEncaissement),
      if (reference != null) 'reference': reference,
      if (commentaire != null) 'commentaire': commentaire,
    });
    return ResultatVersementLot.fromJson(data as Map<String, dynamic>);
  }

  Future<Versement> getVersement(String versementId) async {
    final data = await _client.get('/versements/$versementId');
    return Versement.fromJson(data as Map<String, dynamic>);
  }
}
