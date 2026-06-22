import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/token_model.dart';

/// Datasource distant — appels HTTP bruts vers /api/auth/*.
/// Lance uniquement des [ApiException] ou [NetworkException].
/// Ne connaît pas [Failure] ni le domain.
class AuthRemoteDatasource {
  final ApiClient _client;
  const AuthRemoteDatasource(this._client);

  Future<TokenModel> login(String username, String password) async {
    final data = await _client.post('/auth/login', {
          'username': username,
          'password': password,
        }) as Map<String, dynamic>;
    return TokenModel.fromJson(data);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    await _client.post('/auth/register', {
      'username': username,
      'email': email,
      'password': password,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
    });
  }

  Future<TokenModel> refreshToken(String refreshToken) async {
    final data = await _client.post('/auth/refresh', {
          'refreshToken': refreshToken,
        }) as Map<String, dynamic>;
    return TokenModel.fromJson(data);
  }

  Future<void> logout(String refreshToken) async {
    await _client.post('/auth/logout', {'refreshToken': refreshToken});
  }

  Future<void> forgotPassword(String email) async {
    await _client.post('/auth/forgot-password', {'email': email});
  }
}
