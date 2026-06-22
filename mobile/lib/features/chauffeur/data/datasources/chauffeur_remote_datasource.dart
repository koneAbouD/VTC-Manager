import 'dart:typed_data';

import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/chauffeur_model.dart';
import '../models/chauffeur_request_model.dart';

class ChauffeurRemoteDatasource {
  final ApiClient _client;
  const ChauffeurRemoteDatasource(this._client);

  Future<List<ChauffeurModel>> getChauffeurs() async {
    final data = await _client.get('/chauffeurs');
    if (data is! List) throw ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => ChauffeurModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChauffeurModel> getChauffeurById(int id) async {
    final data = await _client.get('/chauffeurs/$id');
    return ChauffeurModel.fromJson(data as Map<String, dynamic>);
  }

  /// POST multipart `/chauffeurs` — conforme à `ChauffeurController#create`.
  /// `data` (JSON `ChauffeurRequest`) + `permis` (fichier) + `photo` (optionnel).
  Future<ChauffeurModel> createChauffeur(
    ChauffeurRequestModel request, {
    Uint8List? permisBytes,
    String permisFilename = 'permis.jpg',
    Uint8List? photoBytes,
    String photoFilename = 'photo.jpg',
  }) async {
    final data = await _client.postMultipart(
      '/chauffeurs',
      data: request.toJson(),
      permisBytes: permisBytes,
      permisFilename: permisFilename,
      photoBytes: photoBytes,
      photoFilename: photoFilename,
    );
    return ChauffeurModel.fromJson(data as Map<String, dynamic>);
  }

  /// PUT multipart `/chauffeurs/{id}` — conforme à
  /// `ChauffeurController#update` : `data` obligatoire, `permis` et `photo`
  /// optionnels (seulement fournis si l'utilisateur a choisi un nouveau
  /// fichier depuis l'écran d'édition).
  Future<ChauffeurModel> updateChauffeur(
    int id,
    ChauffeurRequestModel request, {
    Uint8List? permisBytes,
    String permisFilename = 'permis.jpg',
    Uint8List? photoBytes,
    String photoFilename = 'photo.jpg',
  }) async {
    final data = await _client.putMultipart(
      '/chauffeurs/$id',
      data: request.toJson(),
      permisBytes: permisBytes,
      permisFilename: permisFilename,
      photoBytes: photoBytes,
      photoFilename: photoFilename,
    );
    return ChauffeurModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteChauffeur(int id) => _client.delete('/chauffeurs/$id');

  Future<void> uploadDocumentChauffeur({
    required int chauffeurId,
    required int typeDocumentId,
    required Uint8List bytes,
    required String filename,
    String? reference,
    String? dateEmission,
    String? dateExpiration,
    List<String>? categorie,
    bool? permanent,
  }) async {
    final data = <String, dynamic>{
      'typeDocumentId': typeDocumentId,
      'cible': 'CHAUFFEUR',
      'cibleId': chauffeurId,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (dateEmission != null) 'dateEmission': dateEmission,
      if (dateExpiration != null) 'dateExpiration': dateExpiration,
      if (categorie != null && categorie.isNotEmpty) 'categorie': categorie,
      if (permanent != null) 'permanence': permanent,
    };
    await _client.postMultipartSingle(
      '/v1/documents',
      data: data,
      fileField: 'fichier',
      fileBytes: bytes,
      fileFilename: filename,
      fileContentType: _mimeFromFilename(filename),
    );
  }

  Future<void> deleteDocument(int documentId) =>
      _client.delete('/v1/documents/$documentId');

  Future<void> archiverDocumentChauffeur(int documentId, String raison) =>
      _client.post(
          '/v1/documents/$documentId/archiver', {'raisonArchivage': raison});

  static String _mimeFromFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }

}
