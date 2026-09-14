import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/utils/recu_paiement.dart';

/// Le reçu est ce que le chauffeur garde du versement : il doit dire ce qui a
/// été payé, pour quoi, et ce qui reste — sans jamais afficher un champ vide,
/// qui ferait douter du reste.
void main() {
  RecuPaiement recu({
    String? chauffeur = 'Kouassi Jean',
    String? vehicule = '1234 AB 01',
    List<LigneRecu>? lignes,
    String? reference,
    double? resteDu,
  }) =>
      RecuPaiement(
        chauffeur: chauffeur,
        vehicule: vehicule,
        lignes: lignes ??
            const [LigneRecu(libelle: 'Recette du 10/09/2026', montant: 15000)],
        modePaiement: 'Espèces',
        date: DateTime(2026, 9, 11),
        reference: reference,
        resteDu: resteDu,
      );

  test('un versement unique annonce un montant, sans détail redondant', () {
    final texte = composerRecu(recu());

    expect(texte, contains('Recette du 10/09/2026'));
    expect(texte, contains('Montant reçu'));
    expect(texte, isNot(contains('Total reçu')));
    expect(texte, contains('Kouassi Jean'));
    expect(texte, contains('1234 AB 01'));
    expect(texte, contains('Mode : Espèces'));
    expect(texte, contains('Date : 11/09/2026'));
  });

  test('plusieurs créances soldées sont détaillées puis totalisées', () {
    final texte = composerRecu(recu(lignes: const [
      LigneRecu(libelle: 'Recette du 10/09/2026', montant: 15000),
      LigneRecu(libelle: 'Cotisation du 10/09/2026', montant: 2000),
    ]));

    expect(texte, contains('Recette du 10/09/2026'));
    expect(texte, contains('Cotisation du 10/09/2026'));
    expect(texte, contains('Total reçu'));
    // 17 000 : l'espace des milliers produit par intl n'est pas une espace
    // ordinaire, on ne compare donc que les chiffres.
    expect(texte.replaceAll(RegExp(r'\s'), ''), contains('17000XOF'));
  });

  test('une créance soldée annonce un solde à jour, pas un reste nul', () {
    expect(composerRecu(recu(resteDu: 0)), contains('Solde : à jour'));
    expect(composerRecu(recu(resteDu: 0)), isNot(contains('Reste dû')));
  });

  test('un reste dû est annoncé tel quel', () {
    expect(composerRecu(recu(resteDu: 5000)), contains('Reste dû'));
  });

  // Une recette au réel n'a pas de dû d'avance : le reçu doit alors se taire
  // plutôt qu'annoncer un solde faux.
  test('un dû inconnu ne fait apparaître aucun solde', () {
    final texte = composerRecu(recu());
    expect(texte, isNot(contains('Reste dû')));
    expect(texte, isNot(contains('Solde')));
  });

  test('les champs absents ne laissent pas de libellé vide', () {
    final texte = composerRecu(recu(chauffeur: null, vehicule: null));

    expect(texte, isNot(contains('Chauffeur :')));
    expect(texte, isNot(contains('Véhicule :')));
    expect(texte, isNot(contains('Réf.')));
    expect(texte, isNot(contains('null')));
  });

  test('la référence du paiement figure au reçu quand elle existe', () {
    expect(composerRecu(recu(reference: 'MP240911.1523.A1234')),
        contains('Réf. : MP240911.1523.A1234'));
  });

  // Une écriture sans mode de paiement ne doit pas faire dire au reçu que
  // l'argent est venu en espèces.
  test('un mode de paiement inconnu ne s\'invente pas', () {
    final texte = composerRecu(RecuPaiement(
      chauffeur: 'Kouassi Jean',
      lignes: const [
        LigneRecu(libelle: 'Recette du 10/09/2026', montant: 15000)
      ],
      date: DateTime(2026, 9, 11),
    ));

    expect(texte, isNot(contains('Mode')));
    expect(texte, contains('Date : 11/09/2026'));
    expect(texte, contains('Montant reçu'));
  });
}
