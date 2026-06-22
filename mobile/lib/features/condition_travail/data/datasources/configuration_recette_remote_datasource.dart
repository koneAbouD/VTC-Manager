import '../../../../core/network/api_client.dart';
import '../models/configuration_recette_model.dart';

class ConfigurationRecetteRemoteDatasource {
  final ApiClient _client;

  const ConfigurationRecetteRemoteDatasource(this._client);

  Future<ConfigurationRecetteModel> getConfiguration(int vehiculeId) async {
    final data =
        await _client.get('/vehicules/$vehiculeId/configuration-recette');
    return ConfigurationRecetteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ConfigurationRecetteModel> createConfiguration(
    int vehiculeId,
    ConfigurationRecetteModel configuration,
  ) async {
    final data = await _client.post(
      '/vehicules/$vehiculeId/configuration-recette',
      configuration.toJson(),
    );
    return ConfigurationRecetteModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ConfigurationRecetteModel> updateConfiguration(
    int vehiculeId,
    ConfigurationRecetteModel configuration,
  ) async {
    final data = await _client.put(
      '/vehicules/$vehiculeId/configuration-recette',
      configuration.toJson(),
    );
    return ConfigurationRecetteModel.fromJson(data as Map<String, dynamic>);
  }
}
