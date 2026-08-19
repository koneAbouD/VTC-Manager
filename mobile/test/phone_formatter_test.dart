import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/core/utils/phone_formatter.dart';

TextEditingValue _v(String t, int offset) =>
    TextEditingValue(text: t, selection: TextSelection.collapsed(offset: offset));

void main() {
  group('format', () {
    test('détache l\'indicatif ivoirien et groupe le numéro par paires', () {
      expect(PhoneFormatter.format('+225 0712345678'), '+225 07 12 34 56 78');
      expect(PhoneFormatter.format('+2250712345678'), '+225 07 12 34 56 78');
      expect(PhoneFormatter.format('2250712345678'), '225 07 12 34 56 78');
    });

    test('groupe un numéro local', () {
      expect(PhoneFormatter.format('0712345678'), '07 12 34 56 78');
    });

    test('idempotent sur un numéro déjà groupé', () {
      expect(PhoneFormatter.format('+225 07 12 34 56 78'),
          '+225 07 12 34 56 78');
    });

    test('un local commençant par 225 n\'est pas coupé en indicatif', () {
      // « 22 51 23 45 67 » est un numéro d'abonné à 10 chiffres, pas un
      // indicatif suivi d'un numéro.
      expect(PhoneFormatter.format('2251234567'), '22 51 23 45 67');
    });

    test('autre pays : le numéro suit son séparateur, l\'indicatif reste entier',
        () {
      expect(PhoneFormatter.format('+33 612345678'), '+33 61 23 45 67 8');
      // Sans séparateur, l'indicatif ne se devine pas : on ne coupe pas.
      expect(PhoneFormatter.format('+33612345678'), '+33612345678');
    });

    test('vide ou nul', () {
      expect(PhoneFormatter.format(null), '');
      expect(PhoneFormatter.format('   '), '');
    });
  });

  group('chiffres', () {
    test('retire les séparateurs', () {
      expect(PhoneFormatter.chiffres('+225 07 12 34 56 78'), '2250712345678');
      expect(PhoneFormatter.chiffres(null), '');
    });
  });

  group('formatEditUpdate', () {
    const f = PhoneInputFormatter();

    test('curseur en fin de saisie', () {
      final r = f.formatEditUpdate(_v('071', 3), _v('0712', 4));
      expect(r.text, '07 12');
      expect(r.selection.baseOffset, 5);
    });

    test('curseur au milieu', () {
      // Cinq chiffres précèdent le curseur : il se retrouve derrière le
      // cinquième du texte regroupé — « 07 12 3|4 56 ».
      final r = f.formatEditUpdate(_v('07 12 456', 5), _v('07123456', 5));
      expect(r.text, '07 12 34 56');
      expect(r.selection.baseOffset, 7);
    });

    test('suppression du dernier chiffre', () {
      final r = f.formatEditUpdate(_v('07 12', 5), _v('07 1', 4));
      expect(r.text, '07 1');
      expect(r.selection.baseOffset, 4);
    });

    test('champ vidé', () {
      final r = f.formatEditUpdate(_v('07 12', 5), _v('', 0));
      expect(r.text, '');
      expect(r.selection.baseOffset, 0);
    });
  });
}
