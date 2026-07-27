import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_pin/tmk_pin.dart';

const _theme = PinTheme(
  accent: Color(0xFF43A047),
  digit: Color(0xFF1A1A2E),
  border: Color(0xFFE4E9EE),
  filled: Color(0xFF43A047),
  error: Color(0xFFB71C1C),
);

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('PinKeypad', () {
    testWidgets('affiche les dix chiffres et la touche retour', (tester) async {
      await tester.pumpWidget(host(PinKeypad(
        onDigit: (_) {},
        onBackspace: () {},
        theme: _theme,
      )));

      for (final digit in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        expect(find.text(digit), findsOneWidget);
      }
      expect(find.byIcon(Icons.backspace_rounded), findsOneWidget);
    });

    testWidgets('remonte les frappes et l\'effacement', (tester) async {
      final frappes = <String>[];
      var effacements = 0;

      await tester.pumpWidget(host(PinKeypad(
        onDigit: frappes.add,
        onBackspace: () => effacements++,
        theme: _theme,
      )));

      await tester.tap(find.text('4'));
      await tester.tap(find.text('8'));
      await tester.tap(find.byIcon(Icons.backspace_rounded));

      expect(frappes, ['4', '8']);
      expect(effacements, 1);
    });

    testWidgets('désactivé, aucune frappe ne passe', (tester) async {
      final frappes = <String>[];

      await tester.pumpWidget(host(PinKeypad(
        onDigit: frappes.add,
        onBackspace: () {},
        theme: _theme,
        enabled: false,
      )));

      await tester.tap(find.text('4'));
      expect(frappes, isEmpty);
    });
  });

  group('PinLayout', () {
    testWidgets('tient sur un petit écran, logo abaissé compris',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PinLayout(
            theme: _theme,
            brand: const SizedBox(width: 96, height: 96),
            topSpacing: 48,
            prompt: 'Veuillez saisir votre code TMK',
            message: 'Code incorrect. 4 essais restants.',
            length: PinService.codeLength,
            filled: 2,
            onDigit: (_) {},
            onBackspace: () {},
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Veuillez saisir votre code TMK'), findsOneWidget);
    });

    testWidgets('tient en paysage, où la hauteur manque', (tester) async {
      // Téléphone couché : la pile verticale (barre, pavé, pied de page) ne
      // rentre pas — la mise en page doit basculer en deux colonnes.
      tester.view.physicalSize = const Size(832, 305);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PinLayout(
            theme: _theme,
            brand: const SizedBox(width: 96, height: 96),
            topSpacing: 48,
            prompt: 'Veuillez saisir votre code TMK',
            message: 'Code incorrect. 4 essais restants.',
            length: PinService.codeLength,
            filled: 2,
            footer: const Text('Code TMK oublié ?'),
            onDigit: (_) {},
            onBackspace: () {},
          ),
        ),
      ));

      // Aucun débordement, et le pavé reste utilisable.
      expect(tester.takeException(), isNull);
      for (final digit in ['0', '5', '9']) {
        expect(find.text(digit), findsOneWidget);
      }
      expect(find.text('Code TMK oublié ?'), findsOneWidget);
    });
  });

  group('PinLayout — zone de retour', () {
    Widget page({bool busy = false, String? message}) => MaterialApp(
          home: Scaffold(
            body: PinLayout(
              theme: _theme,
              brand: const SizedBox(width: 96, height: 96),
              prompt: 'Veuillez saisir votre code TMK',
              length: PinService.codeLength,
              filled: 5,
              busy: busy,
              message: message,
              onDigit: (_) {},
              onBackspace: () {},
            ),
          ),
        );

    void ecran(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('le loader est centré horizontalement', (tester) async {
      ecran(tester);

      await tester.pumpWidget(page(busy: true));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.getCenter(find.byType(CircularProgressIndicator)).dx,
        closeTo(200, 0.5),
      );
    });

    testWidgets('le message de refus est centré horizontalement',
        (tester) async {
      ecran(tester);
      const refus = 'Code incorrect. 4 essais restants.';

      await tester.pumpWidget(page(message: refus));
      await tester.pump(const Duration(milliseconds: 300));

      // C'est la pastille entière qu'on mesure : le texte, lui, est décalé par
      // l'icône qui le précède.
      final pastille =
          find.ancestor(of: find.text(refus), matching: find.byType(Row)).first;
      expect(tester.getCenter(pastille).dx, closeTo(200, 0.5));
    });
  });

  group('PinBoxes', () {
    testWidgets('une case par chiffre attendu', (tester) async {
      await tester.pumpWidget(host(const PinBoxes(
        length: PinService.codeLength,
        filled: 2,
        theme: _theme,
      )));

      expect(
        find.byType(AnimatedContainer),
        findsNWidgets(PinService.codeLength),
      );
    });

    testWidgets('tiennent dans un écran étroit', (tester) async {
      // 5 × 58 + 4 × 14 = 346 : ça ne rentre pas dans 320 dp de large.
      await tester.pumpWidget(host(const SizedBox(
        width: 320,
        child: PinBoxes(
          length: PinService.codeLength,
          filled: 0,
          theme: _theme,
        ),
      )));

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AnimatedContainer).first).width,
        lessThanOrEqualTo(58.0),
      );
    });

    testWidgets('secoue quand errorTick change', (tester) async {
      await tester.pumpWidget(host(const PinBoxes(
        length: 5,
        filled: 5,
        theme: _theme,
      )));

      Offset position() => tester.getTopLeft(find.byType(Row).first);
      final repos = position();

      await tester.pumpWidget(host(const PinBoxes(
        length: 5,
        filled: 5,
        theme: _theme,
        errorTick: 1,
      )));
      await tester.pump(const Duration(milliseconds: 60));

      expect(position().dx, isNot(repos.dx));

      // L'animation retombe sur ses pieds.
      await tester.pumpAndSettle();
      expect(position().dx, closeTo(repos.dx, 0.5));
    });
  });
}
