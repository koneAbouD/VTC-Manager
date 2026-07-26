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
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
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
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));

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
