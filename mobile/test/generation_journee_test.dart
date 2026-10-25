import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/recette/domain/entities/generation_journee.dart';

/// Bilan du bouton « générer » de la page Recettes : recettes et cotisations
/// d'un seul geste, un verdict par côté.
void main() {
  GenerationJournee bilan(Map<String, dynamic> json) =>
      GenerationJournee.fromJson({'date': '2026-10-24', ...json});

  test('lit la réponse du serveur', () {
    final b = bilan({'recettes': 4, 'cotisations': 6});
    expect(b.date, DateTime(2026, 10, 24));
    expect(b.recettes, 4);
    expect(b.cotisations, 6);
    expect(b.enErreur, isFalse);
  });

  test('les deux réussies : un seul message avec les deux compteurs', () {
    expect(bilan({'recettes': 4, 'cotisations': 6}).message,
        "Lignes d'hier générées : 4 recettes, 6 cotisations.");
    expect(bilan({'recettes': 1, 'cotisations': 0}).message,
        "Lignes d'hier générées : 1 recette, aucune cotisation due.");
  });

  test("un côté en échec : son motif s'affiche, l'autre garde son compteur", () {
    final b = bilan({
      'recettes': 4,
      'cotisations': 0,
      'erreurCotisations': 'Période clôturée',
    });
    expect(b.enErreur, isTrue);
    expect(b.recettesReussies, isTrue);
    expect(b.cotisationsReussies, isFalse);
    expect(b.message, '4 recettes\nCotisations : Période clôturée');
  });

  test('les deux en échec : deux motifs', () {
    final b = bilan({
      'erreurRecettes': 'Refus A',
      'erreurCotisations': 'Refus B',
    });
    expect(b.recettesReussies || b.cotisationsReussies, isFalse);
    expect(b.message, 'Recettes : Refus A\nCotisations : Refus B');
  });
}
