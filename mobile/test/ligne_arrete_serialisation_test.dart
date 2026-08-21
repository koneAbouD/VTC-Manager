import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/tresorerie/domain/entities/compte_courant.dart';

/// Une ligne de créance dit deux choses différentes : ce que l'arrêté en éteint
/// (`montant`) et ce que le document doit encore (`restant`). Les confondre est
/// exactement l'erreur que l'écran commettait — une recette de 10 000 couverte à
/// 3 000 s'affichait « 3 000 » et passait pour soldée.
///
/// Le serveur ne sert `restant` qu'à l'aperçu : sur un arrêté enregistré, le
/// snapshot ne fige que ce qui a été fait. `du` porte ce repli.
void main() {
  test('une ligne d\'aperçu distingue la part compensée du reste dû', () {
    final ligne = LigneArrete.fromJson({
      'document': 'RECETTE',
      'documentId': 100,
      'chauffeurId': 7,
      'vehiculeId': 3,
      'dateDocument': '2026-08-12',
      'montant': 3000,
      'restant': 10000,
      'sens': 'DEBIT',
    });

    expect(ligne.montant, 3000);
    expect(ligne.restant, 10000);
    expect(ligne.du, 10000);
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
    expect(ligne.estCredit, isTrue);
  });
}
