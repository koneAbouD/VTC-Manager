import 'dart:typed_data';

import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/page_result.dart';
import '../models/apercu_import_model.dart';
import '../models/apercu_reversement_model.dart';
import '../models/contravention_model.dart';

class ContraventionRemoteDatasource {
  final ApiClient _client;
  const ContraventionRemoteDatasource(this._client);

  /// Liste paginée (scroll infini) via `GET /contraventions/page`.
  Future<PageResult<ContraventionModel>> getContraventionsPage({
    int page = 0,
    int size = 20,
    int? chauffeurId,
    int? vehiculeId,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (chauffeurId != null) 'chauffeurId': '$chauffeurId',
      if (vehiculeId != null) 'vehiculeId': '$vehiculeId',
    };
    final data = await _client.get('/contraventions/page', query: query);
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return PageResult.fromJson(data, (e) => ContraventionModel.fromJson(e));
  }

  Future<List<ContraventionModel>> getContraventions() async {
    final data = await _client.get('/contraventions');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => ContraventionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ContraventionModel> getContraventionById(int id) async {
    final data = await _client.get('/contraventions/$id');
    return ContraventionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ContraventionModel> createContravention(
      ContraventionModel contravention) async {
    final data = await _client.post('/contraventions', contravention.toJson());
    return ContraventionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ContraventionModel> updateContravention(
      int id, ContraventionModel contravention) async {
    final data =
        await _client.put('/contraventions/$id', contravention.toJson());
    return ContraventionModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteContravention(int id) =>
      _client.delete('/contraventions/$id');

  /// Récupère les octets du document source archivé (relevé PDF) d'une
  /// contravention via `GET /contraventions/{id}/document`.
  Future<Uint8List> getDocumentBytes(int id) =>
      _client.getBytes('/contraventions/$id/document');

  Future<ContraventionModel> payContravention(
      int id, double montantPaye) async {
    final data = await _client
        .post('/contraventions/$id/payments', {'montantPaye': montantPaye});
    return ContraventionModel.fromJson(data as Map<String, dynamic>);
  }

  /// Reverse la contravention à l'État : crée l'opération financière de
  /// catégorie « Reversement contravention » (`POST /contraventions/{id}/reverse`).
  Future<ContraventionModel> reverser(int id) async {
    final data = await _client.post('/contraventions/$id/reverse', const {});
    return ContraventionModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Import PDF (Mode 1) ────────────────────────────────────────────────────

  /// Téléverse un relevé PDF et récupère l'aperçu (rien n'est persisté).
  Future<ApercuImportModel> importerReleve(
      Uint8List pdfBytes, String filename) async {
    final data = await _client.postMultipartSingle(
      '/contraventions/importer',
      data: const {},
      fileField: 'fichier',
      fileBytes: pdfBytes,
      fileFilename: filename,
      fileContentType: 'application/pdf',
    );
    return ApercuImportModel.fromJson(data as Map<String, dynamic>);
  }

  /// Confirme l'import des contraventions révisées. Retourne le bilan brut.
  Future<Map<String, dynamic>> confirmerImport(
      List<ContraventionModel> items) async {
    final data = await _client.post('/contraventions/confirmer', {
      'contraventions': items.map((c) => c.toImportItemJson()).toList(),
    });
    return data as Map<String, dynamic>;
  }

  // ── Reversement par quittance de l'État ─────────────────────────────────

  /// Téléverse une quittance de paiement (PDF) et récupère l'aperçu rapproché
  /// (`POST /contraventions/reversements/importer`). Rien n'est reversé.
  Future<ApercuReversementModel> importerQuittance(
      Uint8List fileBytes, String filename) async {
    final data = await _client.postMultipartSingle(
      '/contraventions/reversements/importer',
      data: const {},
      fileField: 'fichier',
      fileBytes: fileBytes,
      fileFilename: filename,
      fileContentType: 'application/pdf',
    );
    return ApercuReversementModel.fromJson(data as Map<String, dynamic>);
  }

  /// Confirme le reversement des contraventions sélectionnées
  /// (`POST /contraventions/reversements/confirmer`). Retourne le bilan brut.
  Future<Map<String, dynamic>> confirmerReversement(
      List<int> contraventionIds, String? referenceQuittance) async {
    final data = await _client.post('/contraventions/reversements/confirmer', {
      'referenceQuittance': referenceQuittance,
      'contraventionIds': contraventionIds,
    });
    return data as Map<String, dynamic>;
  }
}
