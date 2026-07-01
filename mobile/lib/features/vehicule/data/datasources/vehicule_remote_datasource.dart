import 'dart:typed_data';

import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/page_result.dart';
import '../models/vehicule_model.dart';
import '../models/vehicule_photo_model.dart';

class VehiculeRemoteDatasource {
  final ApiClient _client;
  const VehiculeRemoteDatasource(this._client);

  Future<List<VehiculeModel>> getVehicules() async {
    final data = await _client.get('/vehicules');
    if (data is! List) throw const ApiException(500, 'Format de réponse inattendu');
    return data
        .map((e) => VehiculeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Liste paginée (scroll infini) via `GET /vehicules/page`.
  Future<PageResult<VehiculeModel>> getVehiculesPage({
    int page = 0,
    int size = 20,
    String? statut,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (statut != null) 'statut': statut,
    };
    final data = await _client.get('/vehicules/page', query: query);
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return PageResult.fromJson(data, (e) => VehiculeModel.fromJson(e));
  }

  Future<VehiculeModel> getVehiculeById(int id) async {
    final data = await _client.get('/vehicules/$id');
    return VehiculeModel.fromJson(data as Map<String, dynamic>);
  }

  Future<VehiculeModel> createVehicule(VehiculeModel vehicule) async {
    final data = await _client.post('/vehicules', vehicule.toJson());
    return VehiculeModel.fromJson(data as Map<String, dynamic>);
  }

  Future<VehiculeModel> updateVehicule(int id, VehiculeModel vehicule) async {
    final data = await _client.put('/vehicules/$id', vehicule.toJson());
    return VehiculeModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteVehicule(int id) => _client.delete('/vehicules/$id');

  // ── Photos ───────────────────────────────────────────────────────────────

  Future<List<VehiculePhotoModel>> getPhotos(int vehiculeId) async {
    final data = await _client.get('/vehicules/$vehiculeId/photos');
    if (data is! List) return [];
    return data
        .map((e) => VehiculePhotoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<VehiculePhotoModel> uploadPhoto(
      int vehiculeId, Uint8List bytes, String filename) async {
    final data = await _client.postFile(
      '/vehicules/$vehiculeId/photos',
      bytes: bytes,
      filename: filename,
    );
    return VehiculePhotoModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deletePhoto(int vehiculeId, int photoId) =>
      _client.delete('/vehicules/$vehiculeId/photos/$photoId');

  // ── Documents ────────────────────────────────────────────────────────────

  Future<void> uploadDocument({
    required int vehiculeId,
    required int typeDocumentId,
    required Uint8List bytes,
    required String filename,
    String? reference,
    String? dateEmission,
    String? dateExpiration,
    bool permanent = false,
  }) async {
    final data = <String, dynamic>{
      'typeDocumentId': typeDocumentId,
      'cible': 'VEHICULE',
      'cibleId': vehiculeId,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (dateEmission != null) 'dateEmission': dateEmission,
      if (!permanent && dateExpiration != null) 'dateExpiration': dateExpiration,
      'permanence': permanent,
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

  Future<void> deleteDocument(int documentId) =>
      _client.delete('/v1/documents/$documentId');

  Future<void> archiverDocument(int documentId, String raison) =>
      _client.post('/v1/documents/$documentId/archiver',
          {'raisonArchivage': raison});
}
