import '../../../../core/network/api_client.dart';
import '../models/profil_model.dart';
import '../models/solde_model.dart';

/// Accès distant au profil et aux soldes du chauffeur (`/me/profil`, `/me/solde`).
class CompteRemoteDatasource {
  final ApiClient _client;
  const CompteRemoteDatasource(this._client);

  Future<ProfilModel> getProfil() async {
    final data = await _client.get('/me/profil');
    return ProfilModel.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<SoldeModel> getSolde() async {
    final data = await _client.get('/me/solde');
    return SoldeModel.fromJson((data as Map).cast<String, dynamic>());
  }
}
