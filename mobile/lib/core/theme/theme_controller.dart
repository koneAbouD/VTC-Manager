import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../storage/secure_storage.dart';
import 'app_palette.dart';

/// Apparence choisie par l'utilisateur : couleur d'accent et mode d'éclairage.
@immutable
class ThemeSettings {
  final AppAccent accent;
  final ThemeMode mode;

  const ThemeSettings({
    this.accent = AppAccent.vert,
    this.mode = ThemeMode.light,
  });

  ThemeSettings copyWith({AppAccent? accent, ThemeMode? mode}) =>
      ThemeSettings(accent: accent ?? this.accent, mode: mode ?? this.mode);

  /// Relit le choix enregistré. Lu **avant** `runApp` : l'application s'ouvre
  /// directement dans la bonne apparence, sans clignotement vert-clair.
  static Future<ThemeSettings> charger(SecureStorage storage) async {
    try {
      final accent = AppAccent.depuis(await storage.getThemeAccent());
      final brut = await storage.getThemeMode();
      final mode = ThemeMode.values.firstWhere(
        (m) => m.name == brut,
        orElse: () => ThemeMode.light,
      );
      return ThemeSettings(accent: accent, mode: mode);
    } catch (_) {
      // Coffre illisible : une apparence par défaut vaut mieux qu'un écran noir.
      return const ThemeSettings();
    }
  }
}

/// Valeur de départ du contrôleur, fournie par `main` après lecture du coffre.
final themeSettingsInitialProvider =
    Provider<ThemeSettings>((_) => const ThemeSettings());

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);

class ThemeController extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() => ref.read(themeSettingsInitialProvider);

  Future<void> choisirAccent(AppAccent accent) async {
    if (accent == state.accent) return;
    state = state.copyWith(accent: accent);
    await _ecrire(
        () => ref.read(secureStorageProvider).setThemeAccent(accent.name));
  }

  Future<void> choisirMode(ThemeMode mode) async {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode);
    await _ecrire(
        () => ref.read(secureStorageProvider).setThemeMode(mode.name));
  }

  /// L'apparence est déjà appliquée : un échec d'écriture n'a pas à la défaire,
  /// le choix serait simplement perdu au prochain lancement.
  Future<void> _ecrire(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }
}
