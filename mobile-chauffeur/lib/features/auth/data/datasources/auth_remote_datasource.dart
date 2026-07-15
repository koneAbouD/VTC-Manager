import '../../../../core/network/api_client.dart';
import '../models/auth_tokens_model.dart';

/// Accès distant à l'authentification (OTP WhatsApp + mot de passe).
class AuthRemoteDatasource {
  final ApiClient _client;
  const AuthRemoteDatasource(this._client);

  Future<void> requestOtp(String telephone) async {
    await _client.post('/auth/otp/request', {'telephone': telephone});
  }

  Future<AuthTokensModel> verifyOtp(String telephone, String code) async {
    final data = await _client.post('/auth/otp/verify', {
      'telephone': telephone,
      'code': code,
    });
    return AuthTokensModel.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AuthTokensModel> passwordLogin(
      String identifiant, String motDePasse) async {
    final data = await _client.post('/auth/chauffeur/login', {
      'identifiant': identifiant,
      'motDePasse': motDePasse,
    });
    return AuthTokensModel.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> setPassword(String motDePasse) async {
    await _client.post('/me/mot-de-passe', {'motDePasse': motDePasse});
  }
}
