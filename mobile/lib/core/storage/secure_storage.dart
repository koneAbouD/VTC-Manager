import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper autour de [FlutterSecureStorage].
/// Point unique d'accès au stockage sécurisé des tokens.
class SecureStorage {
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kAccessExpiry = 'access_token_expiry'; // epoch ms
  static const _kLoggedOut = 'session_logged_out';

  final FlutterSecureStorage _storage;

  const SecureStorage([
    FlutterSecureStorage? storage,
  ]) : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  /// Date d'expiration de l'access token (null si inconnue).
  Future<DateTime?> getAccessTokenExpiry() async {
    final raw = await _storage.read(key: _kAccessExpiry);
    final ms = int.tryParse(raw ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String? refreshToken,
    int? expiresInSeconds,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _kRefreshToken, value: refreshToken);
    }
    if (expiresInSeconds != null) {
      final expiry = DateTime.now()
          .add(Duration(seconds: expiresInSeconds))
          .millisecondsSinceEpoch;
      await _storage.write(key: _kAccessExpiry, value: expiry.toString());
    }
  }

  /// Réinstalle le seul refresh token, sans toucher à l'access token.
  ///
  /// Utilisé au déverrouillage par code : le token sort du coffre chiffré et
  /// redevient exploitable par [SessionManager] le temps de la session.
  Future<void> saveRefreshToken(String refreshToken) =>
      _storage.write(key: _kRefreshToken, value: refreshToken);

  /// Efface les tokens **en clair**. Le coffre du code d'accès, qui vit sous
  /// d'autres clés, n'est pas concerné : c'est lui qui permettra de rouvrir la
  /// session au prochain lancement.
  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kAccessExpiry);
  }

  Future<bool> hasAccessToken() async {
    final t = await getAccessToken();
    return t != null && t.isNotEmpty;
  }

  /// La session a été fermée volontairement (déconnexion), par opposition à
  /// simplement verrouillée.
  ///
  /// Le coffre du code survit à une déconnexion, mais le refresh token qu'il
  /// contient est révoqué : sans ce drapeau, le démarrage suivant proposerait
  /// un déverrouillage voué à l'échec. Levé jusqu'à ce qu'un code soit repris
  /// ou installé sur une session neuve. Survit volontairement à [clearTokens].
  Future<bool> isLoggedOut() async =>
      (await _storage.read(key: _kLoggedOut)) == 'true';

  Future<void> setLoggedOut(bool loggedOut) async {
    if (loggedOut) {
      await _storage.write(key: _kLoggedOut, value: 'true');
    } else {
      await _storage.delete(key: _kLoggedOut);
    }
  }
}
