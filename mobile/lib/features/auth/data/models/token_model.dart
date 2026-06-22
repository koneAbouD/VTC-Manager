import '../../domain/entities/token.dart';

/// DTO réseau pour les tokens — sait se désérialiser depuis JSON et
/// se convertir en entité domaine [Token].
class TokenModel extends Token {
  const TokenModel({
    required super.accessToken,
    super.refreshToken,
    required super.expiresIn,
    super.refreshExpiresIn,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) => TokenModel(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 3600,
        refreshExpiresIn: (json['refreshExpiresIn'] as num?)?.toInt(),
      );
}
