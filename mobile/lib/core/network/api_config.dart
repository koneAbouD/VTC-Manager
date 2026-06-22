import 'package:flutter/foundation.dart';

/// Configuration réseau centralisée.
///
/// ┌─────────────────────────────────────────────────────────────────────────┐
/// │  LANCEMENT SUR VRAI TÉLÉPHONE (USB ou wireless ADB)                     │
/// │                                                                         │
/// │  Prérequis unique (une fois par session ADB) :                          │
/// │    adb reverse tcp:8081 tcp:8081                                        │
/// │  → localhost:8081 sur le téléphone = port 8081 du Mac (tunnel ADB)     │
/// │  → Fonctionne sans connaître l'IP, depuis Android Studio ou VS Code.   │
/// │                                                                         │
/// │  Option A — Script auto (recommandé, fait adb reverse automatiquement) │
/// │    ./run_device.sh                                                      │
/// │                                                                         │
/// │  Option B — Android Studio / autre IDE :                                │
/// │    1. adb reverse tcp:8081 tcp:8081   (terminal, une fois)             │
/// │    2. Lancer l'app normalement                                          │
/// │                                                                         │
/// │  Option C — IP fixe (si adb reverse impossible) :                      │
/// │    flutter run --dart-define=DEV_HOST=172.20.10.3                      │
/// └─────────────────────────────────────────────────────────────────────────┘
class ApiConfig {
  static const _port = 8081;

  /// URL complète (priorité absolue)
  static const String _urlOverride  = String.fromEnvironment('API_BASE_URL');

  /// Host seul — IP (192.168.x.x)
  static const String _hostOverride = String.fromEnvironment('DEV_HOST');

  static String get baseUrl {
    // 1. URL complète explicite
    if (_urlOverride.isNotEmpty) return _strip(_urlOverride);

    // 2. Host seul → on construit l'URL
    if (_hostOverride.isNotEmpty) {
      return 'http://${_hostOverride.trim()}:$_port/api';
    }

    // 3. Android (émulateur ou vrai téléphone)
    //    Sur émulateur        : localhost:port est redirigé par adb reverse OU
    //                           on peut aussi utiliser 10.0.2.2 (loopback hôte émulateur).
    //    Sur vrai téléphone   : nécessite `adb reverse tcp:8081 tcp:8081` au préalable,
    //                           ce qui fait de localhost:8081 un tunnel vers le Mac.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://localhost:$_port/api';
    }

    // 4. iOS Simulator / macOS
    return 'http://localhost:$_port/api';
  }

  static String _strip(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
