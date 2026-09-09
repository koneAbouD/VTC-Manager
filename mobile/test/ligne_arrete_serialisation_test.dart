import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/tresorerie/domain/entities/compte_courant.dart';

/// Une ligne de créance dit trois choses différentes : ce que le document
/// réclamait (`montantDu`), ce qu'il doit encore (`restant`), et ce que cet
/// arrêté en éteint (`montant`). Les confondre est exactement l'erreur que
/// l'écran commettait — une recette attendue de 21 000 couverte à 3 000
/// s'affichait « 3 000 » et passait pour une recette de 3 000.
///
/// Le serveur ne sert `restant` et `montantDu` qu'à l'aperçu : sur un arrêté
/// enregistré, le snapshot ne fige que ce qui a été fait. `du` et `origine`
/// portent ce repli.
void main() {
  test('une ligne d\'aperçu distingue l\'attendu, le reste dû et la part compensée',
      () {
    final ligne = LigneArrete.fromJson({
      'document': 'RECETTE',
      'documentId': 100,
      'chauffeurId': 7,
      'vehiculeId': 3,
      'dateDocument': '2026-08-12',
      'montant': 3000,
      'restant': 10000,
      'montantDu': 21000,
      'sens': 'DEBIT',
    });

    expect(ligne.montant, 3000);
    expect(ligne.restant, 10000);
    expect(ligne.du, 10000);
    expect(ligne.montantDu, 21000);
    expect(ligne.origine, 21000);
    expect(ligne.estCredit, isFalse);
    expect(ligne.dateDocument, DateTime(2026, 8, 12));
  });

  test('sans restant servi, le dû retombe sur le montant figé', () {
    final ligne = LigneArrete.fromJson({
      'document': 'COTISATION',
      'documentId': 55,
      'montant': 5000,
      'sens': 'CREDIT',
    });

    expect(ligne.restant, isNull);
    expect(ligne.du, 5000);
    expect(ligne.montantDu, isNull);
    expect(ligne.origine, 5000);
    expect(ligne.estCredit, isTrue);
  });
}
