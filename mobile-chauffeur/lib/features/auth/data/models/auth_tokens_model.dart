import '../../domain/entities/auth_tokens.dart';

class AuthTokensModel extends AuthTokens {
  const AuthTokensModel({
    required super.accessToken,
    super.refreshToken,
    super.expiresInSeconds,
  });

  factory AuthTokensModel.fromJson(Map<String, dynamic> j) => AuthTokensModel(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String?,
        expiresInSeconds: (j['expiresIn'] as num?)?.toInt(),
      );
}
