import '../../../core/network/api_client.dart';

/// Un jour férié tel que renvoyé par l'API.
class JourFerie {
  final int id;
  final DateTime date;
  final String libelle;
  final String type; // FIXE | CHRETIEN | MUSULMAN | AUTRE
  final int annee;
  final String source; // AUTO | MANUEL

  const JourFerie({
    required this.id,
    required this.date,
    required this.libelle,
    required this.type,
    required this.annee,
    required this.source,
  });

  factory JourFerie.fromJson(Map<String, dynamic> j) => JourFerie(
        id: j['id'] as int,
        date: DateTime.parse(j['date'] as String),
        libelle: j['libelle'] as String? ?? '',
        type: j['type'] as String? ?? 'AUTRE',
        annee: j['annee'] as int? ?? DateTime.parse(j['date'] as String).year,
        source: j['source'] as String? ?? 'MANUEL',
      );

  bool get isManuel => source == 'MANUEL';
}

/// Accès REST aux jours fériés (endpoints /api/jours-feries).
class JourFerieApi {
  final ApiClient _client;

  const JourFerieApi(this._client);

  Future<List<JourFerie>> lister(int annee) async {
    final res = await _client.get('/jours-feries', query: {'annee': '$annee'});
    return (res as List<dynamic>)
        .map((e) => JourFerie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JourFerie> ajouter({
    required DateTime date,
    required String libelle,
    String type = 'MUSULMAN',
  }) async {
    final res = await _client.post('/jours-feries', {
      'date': _fmtDate(date),
      'libelle': libelle,
      'type': type,
    });
    return JourFerie.fromJson(res as Map<String, dynamic>);
  }

  /// Génère les fériés déterministes (fixes + chrétiens) de l'année.
  Future<List<JourFerie>> genererAnnee(int annee) async {
    final res = await _client.post('/jours-feries/seed', const {},
        query: {'annee': '$annee'});
    return (res as List<dynamic>)
        .map((e) => JourFerie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> supprimer(int id) => _client.delete('/jours-feries/$id');

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
