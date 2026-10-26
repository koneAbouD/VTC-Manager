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

  /// Dernières réponses reçues, à afficher en attendant le serveur (`null`
  /// si rien n'est en cache).
  Future<ProfilModel?> getProfilEnCache() async {
    final data = await _client.lireCache('/me/profil');
    return data is Map ? ProfilModel.fromJson(data.cast<String, dynamic>()) : null;
  }

  Future<SoldeModel?> getSoldeEnCache() async {
    final data = await _client.lireCache('/me/solde');
    return data is Map ? SoldeModel.fromJson(data.cast<String, dynamic>()) : null;
  }
}
