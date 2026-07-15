import 'package:flutter/foundation.dart';

/// Configuration réseau centralisée.
///
/// Résolution de l'URL de base, par ordre de priorité :
///   1. --dart-define=API_BASE_URL=...   (URL complète, écrase tout)
///   2. --dart-define=DEV_HOST=192.168.x.x  (host seul, port 8081)
///   3. Build RELEASE  → VPS de production (_prodBaseUrl)
///   4. Build DEBUG    → localhost (développement local)
///
/// ┌─────────────────────────────────────────────────────────────────────────┐
/// │  PRODUCTION                                                              │
/// │    flutter build apk --release                                          │
/// │    → cible automatiquement le VPS (_prodBaseUrl)                        │
/// │                                                                         │
/// │  DÉVELOPPEMENT (vrai téléphone via tunnel ADB)                          │
/// │    adb reverse tcp:8081 tcp:8081   (une fois par session)               │
/// │    flutter run                                                          │
/// │    → localhost:8081 = backend local sur le Mac                          │
/// │                                                                         │
/// │  CAS PARTICULIERS                                                       │
/// │    flutter run --dart-define=DEV_HOST=172.20.10.3   (IP du Mac sur LAN) │
/// │    flutter run --dart-define=API_BASE_URL=http://155.133.27.101:5001/api│
/// └─────────────────────────────────────────────────────────────────────────┘
class ApiConfig {
  static const _port = 8081;

  /// URL de l'API en production (VPS, servie via nginx → /api).
  static const String _prodBaseUrl = 'http://155.133.27.101:5001/api';

  /// URL complète (priorité absolue)
  static const String _urlOverride = String.fromEnvironment('API_BASE_URL');

  /// Host seul — IP (192.168.x.x)
  static const String _hostOverride = String.fromEnvironment('DEV_HOST');

  static String get baseUrl {
    // 1. URL complète explicite (override de build)
    if (_urlOverride.isNotEmpty) return _strip(_urlOverride);

    // 2. Host seul → on construit l'URL
    if (_hostOverride.isNotEmpty) {
      return 'http://${_hostOverride.trim()}:$_port/api';
    }

    // 3. Build release → VPS de production
    if (kReleaseMode) return _prodBaseUrl;

    // 4. Build debug → backend local
    //    (sur vrai téléphone, nécessite `adb reverse tcp:8081 tcp:8081`)
    return 'http://localhost:$_port/api';
  }

  static String _strip(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
