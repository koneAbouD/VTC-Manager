import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/facture_partenaire.dart';
import '../../domain/entities/partenaire.dart';
import '../../domain/entities/type_partenaire.dart';

String _isoDate(DateTime d) => d.toIso8601String().split('T').first;

/// Accès aux partenaires et à leurs factures.
class PartenaireRemoteDatasource {
  final ApiClient _client;
  const PartenaireRemoteDatasource(this._client);

  // ── Types de partenaire (référentiel) ─────────────────────────────────

  /// Types actifs, pour les listes de saisie. Le paramétrage, lui, passe par
  /// l'écran générique des données de référence.
  Future<List<TypePartenaire>> getTypesPartenaire() async {
    final data = await _client.get('/v1/types-partenaire/actifs');
    if (data is! List)
      throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => TypePartenaire.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Partenaires ───────────────────────────────────────────────────────

  Future<List<Partenaire>> getPartenaires({bool actifsSeulement = true}) async {
    final data = await _client
        .get('/partenaires', query: {'actifsSeulement': '$actifsSeulement'});
    if (data is! List)
      throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => Partenaire.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Partenaire> creerPartenaire(Partenaire f) async {
    final data = await _client.post('/partenaires', f.toJson());
    return Partenaire.fromJson(data as Map<String, dynamic>);
  }

  Future<Partenaire> modifierPartenaire(int id, Partenaire f) async {
    final data = await _client.put('/partenaires/$id', f.toJson());
    return Partenaire.fromJson(data as Map<String, dynamic>);
  }

  /// Un partenaire ne se supprime pas : il a un historique comptable.
  Future<Partenaire> changerActivation(int id, bool actif) async {
    final data =
        await _client.patch('/partenaires/$id/activation?actif=$actif');
    return Partenaire.fromJson(data as Map<String, dynamic>);
  }

  // ── Factures ───────────────────────────────────────────────────────────

  /// Échéancier : ce qui reste à payer, échéance la plus ancienne en tête.
  Future<List<FacturePartenaire>> getEcheancier({int? partenaireId}) async {
    final data = await _client.get('/partenaires/factures/echeancier',
        query: partenaireId != null ? {'partenaireId': '$partenaireId'} : null);
    if (data is! List)
      throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => FacturePartenaire.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Factures reçues sur un mois : la charge de la période.
  Future<List<FacturePartenaire>> getFacturesDuMois(int annee, int mois) async {
    final data = await _client.get('/partenaires/factures',
        query: {'annee': '$annee', 'mois': '$mois'});
    if (data is! List)
      throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => FacturePartenaire.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FacturePartenaire> enregistrerFacture({
    required int partenaireId,
    required double montant,
    String? numeroPiece,
    int? categorieId,
    int? vehiculeId,
    DateTime? dateFacture,
    DateTime? dateEcheance,
    String? description,
  }) async {
    final data = await _client.post('/partenaires/factures', {
      'partenaireId': partenaireId,
      'montant': montant,
      if (numeroPiece != null && numeroPiece.isNotEmpty)
        'numeroPiece': numeroPiece,
      if (categorieId != null) 'categorieId': categorieId,
      if (vehiculeId != null) 'vehiculeId': vehiculeId,
      if (dateFacture != null) 'dateFacture': _isoDate(dateFacture),
      if (dateEcheance != null) 'dateEcheance': _isoDate(dateEcheance),
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    return FacturePartenaire.fromJson(data as Map<String, dynamic>);
  }

  Future<FacturePartenaire> reglerFacture({
    required int factureId,
    required double montant,
    String? modePaiement,
    int? compteTresorerieId,
    DateTime? datePaiement,
    String? commentaire,
  }) async {
    final data =
        await _client.post('/partenaires/factures/$factureId/reglements', {
      'montant': montant,
      if (modePaiement != null) 'modePaiement': modePaiement,
      if (compteTresorerieId != null) 'compteTresorerieId': compteTresorerieId,
      if (datePaiement != null) 'datePaiement': _isoDate(datePaiement),
      if (commentaire != null && commentaire.isNotEmpty)
        'commentaire': commentaire,
    });
    return FacturePartenaire.fromJson(data as Map<String, dynamic>);
  }

  /// Dettes laissées par une intervention terminée sans être réglée.
  Future<List<FacturePartenaire>> getFacturesDeMaintenance(
      int maintenanceId) async {
    final data = await _client
        .get('/partenaires/factures/par-maintenance/$maintenanceId');
    if (data is! List)
      throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => FacturePartenaire.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FacturePartenaire> getFacture(int id) async {
    final data = await _client.get('/partenaires/factures/$id');
    return FacturePartenaire.fromJson(data as Map<String, dynamic>);
  }

  /// Historique des règlements : ce qui explique le restant dû.
  Future<List<ReglementFacture>> getReglements(int factureId) async {
    final data =
        await _client.get('/partenaires/factures/$factureId/reglements');
    if (data is! List)
      throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => ReglementFacture.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FacturePartenaire> annulerFacture(int factureId, String motif) async {
    final data = await _client
        .patch('/partenaires/factures/$factureId/annuler', {'motif': motif});
    return FacturePartenaire.fromJson(data as Map<String, dynamic>);
  }
}
