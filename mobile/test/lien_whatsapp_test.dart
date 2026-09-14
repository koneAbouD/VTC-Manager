import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/utils/whatsapp.dart';

/// Le lien qui emmène le guichetier dans WhatsApp. Tout s'y joue : un message
/// mal encodé arrive illisible, et un numéro mal formé ouvre la conversation
/// de quelqu'un d'autre.
void main() {
  test('le numéro local est porté à l\'international', () {
    final lien = lienWhatsApp(telephone: '07 12 34 56 78', message: 'Reçu');
    expect(lien.toString(), startsWith('https://wa.me/2250712345678?text='));
  });

  // Les clients WhatsApp ne redécodent pas tous « + » en espace : un reçu
  // criblé de « + » serait illisible.
  test('les espaces sont encodés en %20, jamais en +', () {
    final lien = lienWhatsApp(telephone: '0712345678', message: 'Montant reçu');
    expect(lien.toString(), contains('Montant%20re%C3%A7u'));
    expect(lien.toString(), isNot(contains('+')));
  });

  test('les retours à la ligne du reçu survivent à l\'encodage', () {
    final lien = lienWhatsApp(telephone: '0712345678', message: 'Ligne 1\nLigne 2');
    expect(lien.toString(), contains('%0A'));
    expect(lien.queryParameters['text'], 'Ligne 1\nLigne 2');
  });

  test('sans numéro exploitable, WhatsApp ouvre son sélecteur de contacts', () {
    expect(lienWhatsApp(telephone: null, message: 'Reçu').toString(),
        startsWith('https://wa.me/?text='));
    expect(lienWhatsApp(telephone: 'à renseigner', message: 'Reçu').toString(),
        startsWith('https://wa.me/?text='));
  });
}
