import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/core/storage/secure_storage.dart';
import 'package:vtc_manager/core/theme/app_colors.dart';
import 'package:vtc_manager/core/theme/app_palette.dart';
import 'package:vtc_manager/core/theme/theme_controller.dart';
import 'package:vtc_manager/features/parametrage/presentation/pages/apparence_page.dart';

void main() {
  tearDown(() => AppColors.appliquer(AppAccent.vert, Brightness.light));

  group('palette', () {
    test("l'apparence par défaut est celle d'origine : vert, clair", () {
      AppColors.appliquer(AppAccent.vert, Brightness.light);
      expect(AppColors.primary, const Color(0xFF43A047));
      expect(AppColors.scaffold, const Color(0xFFF8F9FB));
      expect(AppColors.dark, const Color(0xFF1A1A2E));
      expect(AppColors.blanc, Colors.white);
    });

    test('appliquer ne signale un changement que si la palette diffère', () {
      expect(AppColors.appliquer(AppAccent.vert, Brightness.light), isFalse);
      expect(AppColors.appliquer(AppAccent.bleu, Brightness.light), isTrue);
      expect(AppColors.appliquer(AppAccent.bleu, Brightness.light), isFalse);
      expect(AppColors.appliquer(AppAccent.bleu, Brightness.dark), isTrue);
    });

    test('le thème sombre inverse fonds et texte', () {
      AppColors.appliquer(AppAccent.vert, Brightness.dark);
      expect(AppColors.estSombre, isTrue);
      expect(AppColors.scaffold.computeLuminance(), lessThan(0.1));
      expect(AppColors.dark.computeLuminance(), greaterThan(0.7));
      expect(AppColors.blanc, AppColors.surface);
    });

    test('chaque accent reste lisible : du blanc passe sur sa couleur', () {
      for (final accent in AppAccent.values) {
        for (final b in Brightness.values) {
          final p = AppPalette.de(accent, b);
          // Seuil de contraste de 3:1, celui des éléments graphiques et du
          // gros texte (boutons).
          final l = p.primary.computeLuminance();
          expect((1.05) / (l + 0.05), greaterThan(3.0),
              reason: '${accent.name} / ${b.name}');
        }
      }
    });

    test("un nom d'accent inconnu retombe sur le vert", () {
      expect(AppAccent.depuis(null), AppAccent.vert);
      expect(AppAccent.depuis('fuchsia'), AppAccent.vert);
      expect(AppAccent.depuis('violet'), AppAccent.violet);
    });
  });

  group('persistance', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('rien d\'enregistré : vert, clair', () async {
      final s = await ThemeSettings.charger(const SecureStorage());
      expect(s.accent, AppAccent.vert);
      expect(s.mode, ThemeMode.light);
    });

    test('le choix est écrit puis relu au démarrage suivant', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c
          .read(themeControllerProvider.notifier)
          .choisirAccent(AppAccent.orange);
      await c
          .read(themeControllerProvider.notifier)
          .choisirMode(ThemeMode.dark);

      final relu = await ThemeSettings.charger(const SecureStorage());
      expect(relu.accent, AppAccent.orange);
      expect(relu.mode, ThemeMode.dark);
    });

    test('une valeur altérée ne casse pas le démarrage', () async {
      FlutterSecureStorage.setMockInitialValues(
          {'theme_accent': '???', 'theme_mode': 'noir'});
      final s = await ThemeSettings.charger(const SecureStorage());
      expect(s.accent, AppAccent.vert);
      expect(s.mode, ThemeMode.light);
    });
  });

  testWidgets('la page Apparence applique le choix et le propose en retour',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ApparencePage()),
    ));

    await tester.tap(find.text('Violet'));
    await tester.pump();
    expect(container.read(themeControllerProvider).accent, AppAccent.violet);

    await tester.tap(find.text('Sombre'));
    await tester.pump();
    expect(container.read(themeControllerProvider).mode, ThemeMode.dark);
  });

  testWidgets(
      'reassembleApplication relit les couleurs jusque dans les sous-arbres const',
      (tester) async {
    // Le cas réel : une page affichée sous l'écran de réglages ne se reconstruit
    // pas d'elle-même quand l'accent change.
    await tester.pumpWidget(const MaterialApp(home: _Sonde()));
    expect(tester.widget<ColoredBox>(find.byKey(_sondeKey)).color,
        const Color(0xFF43A047));

    AppColors.appliquer(AppAccent.bleu, Brightness.light);
    await tester.pump();
    expect(tester.widget<ColoredBox>(find.byKey(_sondeKey)).color,
        const Color(0xFF43A047),
        reason: 'sans reassemble, rien ne bouge');

    // Terminé par le frame suivant : on ne l'attend donc pas avant de pumper.
    unawaited(tester.binding.reassembleApplication());
    await tester.pump();
    await tester.pump();
    expect(tester.widget<ColoredBox>(find.byKey(_sondeKey)).color,
        const Color(0xFF1E88E5));
  });
}

const _sondeKey = ValueKey('sonde');

class _Sonde extends StatelessWidget {
  const _Sonde();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(key: _sondeKey, color: AppColors.primary);
}
