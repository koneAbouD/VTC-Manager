import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/core/utils/amount_input_formatter.dart';

TextEditingValue _v(String t, int offset) =>
    TextEditingValue(text: t, selection: TextSelection.collapsed(offset: offset));

void main() {
  group('format', () {
    test('groupe la partie entière', () {
      expect(AmountInputFormatter.format('7500000'), '7 500 000');
      expect(AmountInputFormatter.format('1000'), '1 000');
      expect(AmountInputFormatter.format('999'), '999');
      expect(AmountInputFormatter.format(''), '');
      expect(AmountInputFormatter.format('0'), '0');
    });

    test('conserve signe et décimales', () {
      expect(AmountInputFormatter.format('-1234567'), '-1 234 567');
      expect(AmountInputFormatter.format('7500000.5'), '7 500 000.5');
      expect(AmountInputFormatter.format('12345,75'), '12 345,75');
      expect(AmountInputFormatter.format('1234,'), '1 234,');
    });

    test('idempotent sur du texte déjà groupé', () {
      expect(AmountInputFormatter.format('7 500 000'), '7 500 000');
    });

    test('laisse inchangé ce qui n est pas un nombre', () {
      expect(AmountInputFormatter.format('abc'), 'abc');
      expect(AmountInputFormatter.format('1,2,3'), '1,2,3');
    });
  });

  group('formatEditUpdate', () {
    const f = AmountInputFormatter();

    test('curseur en fin de saisie', () {
      final r = f.formatEditUpdate(_v('750000', 6), _v('7500000', 7));
      expect(r.text, '7 500 000');
      expect(r.selection.baseOffset, 9);
    });

    test('curseur au milieu', () {
      // "1234|567" -> "1 234 567", curseur après le 4e chiffre
      final r = f.formatEditUpdate(_v('123567', 3), _v('1234567', 4));
      expect(r.text, '1 234 567');
      expect(r.selection.baseOffset, 5);
    });

    test('suppression revient sous le millier', () {
      final r = f.formatEditUpdate(_v('1 000', 5), _v('1 00', 4));
      expect(r.text, '100');
      expect(r.selection.baseOffset, 3);
    });

    test('champ vidé', () {
      final r = f.formatEditUpdate(_v('1 000', 5), _v('', 0));
      expect(r.text, '');
      expect(r.selection.baseOffset, 0);
    });
  });
}
