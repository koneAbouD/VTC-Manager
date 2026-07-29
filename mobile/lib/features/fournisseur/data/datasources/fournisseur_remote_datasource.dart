import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/facture_fournisseur.dart';
import '../../domain/entities/fournisseur.dart';

String _isoDate(DateTime d) => d.toIso8601String().split('T').first;

/// Accès aux fournisseurs et à leurs factures.
class FournisseurRemoteDatasource {
  final ApiClient _client;
  const FournisseurRemoteDatasource(this._client);

  // ── Fournisseurs ───────────────────────────────────────────────────────

  Future<List<Fournisseur>> getFournisseurs({bool actifsSeulement = true}) async {
    final data = await _client.get('/fournisseurs',
        query: {'actifsSeulement': '$actifsSeulement'});
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => Fournisseur.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Fournisseur> creerFournisseur(Fournisseur f) async {
    final data = await _client.post('/fournisseurs', f.toJson());
    return Fournisseur.fromJson(data as Map<String, dynamic>);
  }

  Future<Fournisseur> modifierFournisseur(int id, Fournisseur f) async {
    final data = await _client.put('/fournisseurs/$id', f.toJson());
    return Fournisseur.fromJson(data as Map<String, dynamic>);
  }

  /// Un fournisseur ne se supprime pas : il a un historique comptable.
  Future<Fournisseur> changerActivation(int id, bool actif) async {
    final data = await _client.patch('/fournisseurs/$id/activation?actif=$actif');
    return Fournisseur.fromJson(data as Map<String, dynamic>);
  }

  // ── Factures ───────────────────────────────────────────────────────────

  /// Échéancier : ce qui reste à payer, échéance la plus ancienne en tête.
  Future<List<FactureFournisseur>> getEcheancier({int? fournisseurId}) async {
    final data = await _client.get('/fournisseurs/factures/echeancier',
        query: fournisseurId != null ? {'fournisseurId': '$fournisseurId'} : null);
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => FactureFournisseur.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Factures reçues sur un mois : la charge de la période.
  Future<List<FactureFournisseur>> getFacturesDuMois(int annee, int mois) async {
    final data = await _client.get('/fournisseurs/factures',
        query: {'annee': '$annee', 'mois': '$mois'});
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => FactureFournisseur.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FactureFournisseur> enregistrerFacture({
    required int fournisseurId,
    required double montant,
    String? numeroPiece,
    int? categorieId,
    int? vehiculeId,
    DateTime? dateFacture,
    DateTime? dateEcheance,
    String? description,
  }) async {
    final data = await _client.post('/fournisseurs/factures', {
      'fournisseurId': fournisseurId,
      'montant': montant,
      if (numeroPiece != null && numeroPiece.isNotEmpty) 'numeroPiece': numeroPiece,
      if (categorieId != null) 'categorieId': categorieId,
      if (vehiculeId != null) 'vehiculeId': vehiculeId,
      if (dateFacture != null) 'dateFacture': _isoDate(dateFacture),
      if (dateEcheance != null) 'dateEcheance': _isoDate(dateEcheance),
      if (description != null && description.isNotEmpty) 'description': description,
    });
    return FactureFournisseur.fromJson(data as Map<String, dynamic>);
  }

  Future<FactureFournisseur> reglerFacture({
    required int factureId,
    required double montant,
    String? modePaiement,
    int? compteTresorerieId,
    DateTime? datePaiement,
    String? commentaire,
  }) async {
    final data = await _client.post('/fournisseurs/factures/$factureId/reglements', {
      'montant': montant,
      if (modePaiement != null) 'modePaiement': modePaiement,
      if (compteTresorerieId != null) 'compteTresorerieId': compteTresorerieId,
      if (datePaiement != null) 'datePaiement': _isoDate(datePaiement),
      if (commentaire != null && commentaire.isNotEmpty) 'commentaire': commentaire,
    });
    return FactureFournisseur.fromJson(data as Map<String, dynamic>);
  }

  Future<FactureFournisseur> getFacture(int id) async {
    final data = await _client.get('/fournisseurs/factures/$id');
    return FactureFournisseur.fromJson(data as Map<String, dynamic>);
  }

  /// Historique des règlements : ce qui explique le restant dû.
  Future<List<ReglementFacture>> getReglements(int factureId) async {
    final data = await _client.get('/fournisseurs/factures/$factureId/reglements');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => ReglementFacture.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FactureFournisseur> annulerFacture(int factureId, String motif) async {
    final data = await _client
        .patch('/fournisseurs/factures/$factureId/annuler', {'motif': motif});
    return FactureFournisseur.fromJson(data as Map<String, dynamic>);
  }
}
