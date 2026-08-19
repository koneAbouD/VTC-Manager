import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/compte_courant.dart';
import '../../domain/entities/compte_tresorerie.dart';
import '../../domain/entities/creance.dart';
import '../../domain/entities/rapports.dart';

String _isoDate(DateTime d) => d.toIso8601String().split('T').first;

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

  Future<List<CreanceVehicule>> getBalanceAgeeParVehicule() async {
    final data = await _client.get('/finances/balance-agee-vehicule');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => CreanceVehicule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LigneCreance>> getCreancesVehicule(int vehiculeId) async {
    final data = await _client.get('/finances/balance-agee-vehicule/$vehiculeId');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => LigneCreance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Restitution des cotisations : comptes courants + arrêtés ─────────────

  Future<List<CompteCourant>> getComptesCourants(String perimetre) async {
    final data =
        await _client.get('/finances/compte-courant', query: {'perimetre': perimetre});
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => CompteCourant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ArreteCompte> getApercuArrete({
    required String perimetre,
    required int perimetreId,
    required DateTime debut,
    required DateTime fin,
  }) async {
    final data = await _client.get('/finances/arretes/apercu', query: {
      'perimetre': perimetre,
      'perimetreId': '$perimetreId',
      'debut': _isoDate(debut),
      'fin': _isoDate(fin),
    });
    return ArreteCompte.fromJson(data as Map<String, dynamic>);
  }

  /// Lance un arrêté. Passer [cotisationIds]/[creances] non nuls restreint l'arrêté
  /// à une sélection (restitution partielle) ; `null` = arrêté total.
  /// [creances] : liste de `{'document': 'RECETTE'|'PENALITE'|'CONTRAVENTION', 'documentId': int}`.
  Future<ArreteCompte> arreter({
    required String perimetre,
    required int perimetreId,
    required DateTime periodeDebut,
    required DateTime periodeFin,
    DateTime? dateArrete,
    String? modePaiement,
    int? compteTresorerieId,
    List<int>? cotisationIds,
    List<Map<String, dynamic>>? creances,
  }) async {
    final data = await _client.post('/finances/arretes', {
      'perimetre': perimetre,
      'perimetreId': perimetreId,
      'periodeDebut': _isoDate(periodeDebut),
      'periodeFin': _isoDate(periodeFin),
      if (dateArrete != null) 'dateArrete': _isoDate(dateArrete),
      if (modePaiement != null) 'modePaiement': modePaiement,
      if (compteTresorerieId != null) 'compteTresorerieId': compteTresorerieId,
      if (cotisationIds != null) 'cotisationIds': cotisationIds,
      if (creances != null) 'creances': creances,
    });
    return ArreteCompte.fromJson(data as Map<String, dynamic>);
  }

  /// Historique des arrêtés, restreint au mois (annee + mois) si fourni.
  Future<List<ArreteCompte>> getArretes({int? annee, int? mois}) async {
    final data = await _client.get('/finances/arretes', query: {
      if (annee != null) 'annee': '$annee',
      if (mois != null) 'mois': '$mois',
    });
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => ArreteCompte.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ArreteCompte> getArrete(int id) async {
    final data = await _client.get('/finances/arretes/$id');
    return ArreteCompte.fromJson(data as Map<String, dynamic>);
  }

  Future<ArreteCompte> annulerArrete(int id, String motif) async {
    final data =
        await _client.patch('/finances/arretes/$id/annuler', {'motif': motif});
    return ArreteCompte.fromJson(data as Map<String, dynamic>);
  }

  Future<Uint8List> getArretePdf(int id) async {
    return _client.getBytes('/finances/arretes/$id/pdf');
  }

  Future<List<ArreteCompte>> getReleveChauffeur(int chauffeurId) async {
    final data = await _client.get('/finances/arretes/chauffeur/$chauffeurId');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => ArreteCompte.fromJson(e as Map<String, dynamic>))
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

  /// Solde théorique du compte arrêté à [date] : c'est à lui que le serveur
  /// comparera le comptage, et non au solde du jour.
  Future<double> getSoldeALaDate(int compteId, DateTime date) async {
    final data = await _client.get('/comptes-tresorerie/$compteId/solde',
        query: {'date': _isoDate(date)});
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return (data['solde'] as num?)?.toDouble() ?? 0;
  }

  Future<ClotureCaisseData> cloturerCaisse({
    required int compteId,
    required double soldeCompte,
    String? motifEcart,
    DateTime? dateCloture,
  }) async {
    final data = await _client.post('/comptes-tresorerie/$compteId/clotures', {
      'soldeCompte': soldeCompte,
      if (motifEcart != null && motifEcart.isNotEmpty) 'motifEcart': motifEcart,
      if (dateCloture != null) 'dateCloture': _isoDate(dateCloture),
    });
    return ClotureCaisseData.fromJson(data as Map<String, dynamic>);
  }

  /// Relevés d'un compte, du plus récent au plus ancien.
  ///
  /// [inclureAnnules] ramène l'historique complet, relevés retirés compris —
  /// eux seuls expliquent la succession des comptages d'une même journée.
  Future<List<ClotureCaisseData>> getCloturesCaisse(int compteId,
      {bool inclureAnnules = false}) async {
    final data = await _client.get('/comptes-tresorerie/$compteId/clotures',
        query: inclureAnnules ? {'inclureAnnules': 'true'} : null);
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => ClotureCaisseData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Retire un relevé erroné — le procès-verbal reste au dossier, marqué.
  Future<ClotureCaisseData> annulerClotureCaisse(int clotureId, String motif) async {
    final data = await _client.patch(
        '/comptes-tresorerie/clotures/$clotureId/annuler', {'motif': motif});
    return ClotureCaisseData.fromJson(data as Map<String, dynamic>);
  }

  /// Écarts de caisse qui attendent encore une décision, toutes caisses
  /// confondues, du plus ancien au plus récent. Chacun bloque la clôture du
  /// mois où il tombe.
  Future<List<ClotureCaisseData>> getEcartsEnAttente() async {
    final data = await _client.get('/comptes-tresorerie/clotures/ecarts-en-attente');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => ClotureCaisseData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tranche un écart : `PERTE` (l'entreprise le supporte) ou `RECOUVREE`
  /// (le responsable rembourse).
  Future<ClotureCaisseData> imputerEcartCaisse(
      int clotureId, String decision, String motif) async {
    final data = await _client.patch(
        '/comptes-tresorerie/clotures/$clotureId/imputer',
        {'decision': decision, 'motif': motif});
    return ClotureCaisseData.fromJson(data as Map<String, dynamic>);
  }

  /// Revient sur une imputation : ses écritures sont contre-passées et l'écart
  /// redevient à trancher. Pour la décision prise trop vite — le manquant du
  /// mardi qui s'explique le jeudi.
  Future<ClotureCaisseData> annulerImputationEcart(
      int clotureId, String motif) async {
    final data = await _client.patch(
        '/comptes-tresorerie/clotures/$clotureId/annuler-imputation',
        {'motif': motif});
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
    required String base,
  }) async {
    final data = await _client.get('/finances/compte-resultat/par-vehicule',
        query: {'annee': '$annee', 'mois': '$mois', 'base': base});
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

  /// Trésorerie archivée d'un mois clos, compte par compte, avec la date du
  /// comptage qui atteste chaque solde. Vide si le mois n'est pas clos.
  Future<List<SoldeClotureData>> getSoldesCloture(
      {required int annee, required int mois}) async {
    final data =
        await _client.get('/finances/clotures-periode/$annee/$mois/soldes');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => SoldeClotureData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> cloturerPeriode({required int annee, required int mois}) async {
    await _client.post('/finances/clotures-periode', {
      'annee': annee,
      'mois': mois,
    });
  }
}
