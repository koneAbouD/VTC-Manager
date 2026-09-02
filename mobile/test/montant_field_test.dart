import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/widgets/montant_field.dart';

/// Les montants formatés portent les espaces insécables du français.
String _normalise(String texte) =>
    texte.replaceAll(RegExp(r'[   ]'), ' ');

Future<void> _pumpChamp(
  WidgetTester tester,
  TextEditingController controller, {
  required double? plafond,
  bool autoriseVide = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Form(
        child: MontantField(
          controller: controller,
          plafond: plafond,
          autoriseVide: autoriseVide,
          decoration: const InputDecoration(hintText: '0'),
        ),
      ),
    ),
  ));
}

void main() {
  group('lecture d\'un montant saisi', () {
    test('les séparateurs de milliers et la virgule décimale sont admis', () {
      expect(parseMontant('15 000'), 15000);
      expect(parseMontant('1 500,50'), 1500.5);
      expect(parseMontant('1500.50'), 1500.5);
      // Espace insécable, celui que produit le clavier de certains téléphones.
      expect(parseMontant('20 000'), 20000);
    });

    test('ce qui n\'est pas un nombre ne vaut rien', () {
      expect(parseMontant(''), isNull);
      expect(parseMontant('  '), isNull);
      expect(parseMontant('abc'), isNull);
      expect(parseMontant(null), isNull);
    });
  });

  group('refus de saisie', () {
    test('un champ vide est refusé, sauf là où il écarte une ligne', () {
      expect(validerMontant('', plafond: 15000), 'Montant obligatoire');
      expect(validerMontant('', plafond: 15000, autoriseVide: true), isNull);
    });

    test('zéro n\'encaisse rien', () {
      expect(validerMontant('0', plafond: 15000),
          'Le montant doit être positif');
      expect(validerMontant('0', plafond: 15000, autoriseVide: true), isNull);
    });

    test('une saisie qui n\'est pas un nombre est refusée', () {
      expect(validerMontant('abc', plafond: 15000), 'Montant invalide');
    });

    test('au-delà du plafond, le motif dit la limite', () {
      final message = validerMontant('20 000', plafond: 15000);
      expect(_normalise(message!),
          'Dépasse le montant restant (15 000 XOF)');
      // Pile sur la limite, c'est bon : le versement solde la créance.
      expect(validerMontant('15 000', plafond: 15000), isNull);
    });

    test('le message se raccourcit là où le champ est étroit', () {
      final message = validerMontant('9 000',
          plafond: 5000, messageDepassement: (max) => 'Max ${formatMontantCourt(max)}');
      expect(_normalise(message!), 'Max 5 000 XOF');
    });

    test('sans plafond connu, seule la forme du montant est jugée', () {
      expect(validerMontant('999 999', plafond: null), isNull);
    });
  });

  testWidgets('la frappe est regroupée par milliers, les lettres ignorées',
      (tester) async {
    final controller = TextEditingController();
    await _pumpChamp(tester, controller, plafond: 50000);

    await tester.enterText(find.byType(MontantField), '15000');
    await tester.pump();
    expect(controller.text, '15 000');

    await tester.enterText(find.byType(MontantField), '12a34b');
    await tester.pump();
    expect(controller.text, '1 234');
  });

  testWidgets('le dépassement se voit pendant la frappe, sans soumettre',
      (tester) async {
    final controller = TextEditingController();
    await _pumpChamp(tester, controller, plafond: 15000);

    await tester.enterText(find.byType(MontantField), '20000');
    await tester.pumpAndSettle();

    expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data != null &&
            _normalise(w.data!).contains('Dépasse le montant restant')),
        findsOneWidget);
  });
}
