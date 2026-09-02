import '../../../../core/network/api_client.dart';
import '../../domain/entities/conflit_chauffeur.dart';

class CoherenceRemoteDatasource {
  final ApiClient _client;

  CoherenceRemoteDatasource(this._client);

  Future<List<ConflitChauffeur>> getConflitsChauffeur(
      DateTime dateDebut, DateTime dateFin) async {
    final data = await _client.get('/coherence/conflits-chauffeur', query: {
      'dateDebut': dateDebut.toIso8601String().substring(0, 10),
      'dateFin': dateFin.toIso8601String().substring(0, 10),
    });
    return (data as List<dynamic>)
        .map((e) => ConflitChauffeur.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
