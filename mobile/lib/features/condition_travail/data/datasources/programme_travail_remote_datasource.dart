import '../../../../core/network/api_client.dart';
import '../models/programme_travail_model.dart';

class ProgrammeTravailRemoteDatasource {
  final ApiClient _client;

  const ProgrammeTravailRemoteDatasource(this._client);

  Future<ProgrammeTravailModel> getProgramme(int vehiculeId) async {
    final data = await _client.get('/vehicules/$vehiculeId/programme');
    return ProgrammeTravailModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ProgrammeTravailModel> createProgramme(
    int vehiculeId,
    ProgrammeTravailModel programme, {
    bool force = false,
  }) async {
    final data = await _client.post(
      '/vehicules/$vehiculeId/programme',
      programme.toJson(),
      query: force ? {'force': 'true'} : null,
    );
    return ProgrammeTravailModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ProgrammeTravailModel> updateProgramme(
    int vehiculeId,
    ProgrammeTravailModel programme, {
    bool force = false,
  }) async {
    final data = await _client.put(
      '/vehicules/$vehiculeId/programme',
      programme.toJson(),
      query: force ? {'force': 'true'} : null,
    );
    return ProgrammeTravailModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ProgrammeTravailModel> invertProgramme(int vehiculeId) async {
    final data = await _client.post(
      '/vehicules/$vehiculeId/programme/inversion',
      const {},
    );
    return ProgrammeTravailModel.fromJson(data as Map<String, dynamic>);
  }
}
