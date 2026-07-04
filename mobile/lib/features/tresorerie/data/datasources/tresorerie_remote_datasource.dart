import 'dart:convert';

import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/compte_tresorerie.dart';
import '../../domain/entities/creance.dart';
import '../../domain/entities/rapports.dart';

class TresorerieRemoteDatasource {
  final ApiClient _client;
  const TresorerieRemoteDatasource(this._client);

  Future<TresorerieSummary> getSummary({bool actifsSeulement = true}) async {
    final data = await _client.get('/comptes-tresorerie',
        query: {'actifsSeulement': '$actifsSeulement'});
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return TresorerieSummary.fromJson(data);
  }

  Future<List<CreanceChauffeur>> getBalanceAgee() async {
    final data = await _client.get('/finances/balance-agee');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => CreanceChauffeur.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LigneCreance>> getCreancesChauffeur(int chauffeurId) async {
    final data = await _client.get('/finances/balance-agee/$chauffeurId');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => LigneCreance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── V2 : transferts + clôture de caisse ─────────────────────────────────

  Future<void> createTransfert({
    required int compteSourceId,
    required int compteDestinationId,
    required double montant,
    String? commentaire,
  }) async {
    await _client.post('/comptes-tresorerie/transferts', {
      'compteSourceId': compteSourceId,
      'compteDestinationId': compteDestinationId,
      'montant': montant,
      if (commentaire != null && commentaire.isNotEmpty)
        'commentaire': commentaire,
    });
  }

  Future<ClotureCaisseData> cloturerCaisse({
    required int compteId,
    required double soldeCompte,
    String? motifEcart,
  }) async {
    final data = await _client.post('/comptes-tresorerie/$compteId/clotures', {
      'soldeCompte': soldeCompte,
      if (motifEcart != null && motifEcart.isNotEmpty) 'motifEcart': motifEcart,
    });
    return ClotureCaisseData.fromJson(data as Map<String, dynamic>);
  }

  // ── V2/V3 : rapports ─────────────────────────────────────────────────────

  Future<CompteResultatData> getCompteResultat({
    required int annee,
    required int mois,
    required String base,
  }) async {
    final data = await _client.get('/finances/compte-resultat',
        query: {'annee': '$annee', 'mois': '$mois', 'base': base});
    return CompteResultatData.fromJson(data as Map<String, dynamic>);
  }

  Future<List<MargeVehiculeData>> getMargesParVehicule({
    required int annee,
    required int mois,
  }) async {
    final data = await _client.get('/finances/compte-resultat/par-vehicule',
        query: {'annee': '$annee', 'mois': '$mois'});
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => MargeVehiculeData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BilanData> getBilan() async {
    final data = await _client.get('/finances/bilan');
    return BilanData.fromJson(data as Map<String, dynamic>);
  }

  Future<String> getExportComptable({required int annee, required int mois}) async {
    final bytes = await _client
        .getBytes('/finances/export-comptable?annee=$annee&mois=$mois');
    return utf8.decode(bytes);
  }

  Future<List<CloturePeriodeData>> getCloturesPeriode() async {
    final data = await _client.get('/finances/clotures-periode');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => CloturePeriodeData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> cloturerPeriode({required int annee, required int mois}) async {
    await _client.post('/finances/clotures-periode', {
      'annee': annee,
      'mois': mois,
    });
  }
}
