import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/utils/recu_paiement.dart';

/// Le reçu est ce que le chauffeur garde du versement : il doit dire d'emblée
/// ce qui a été reçu, pour quoi, et ce qui reste — sans jamais afficher un champ
/// vide, qui ferait douter du reste.
void main() {
  RecuPaiement recu({
    String? chauffeur = 'Jean Kouassi',
    String? vehicule = '1234 AB 01',
    List<LigneRecu>? lignes,
    String? mode = 'Espèces',
    String? reference,
    double? resteDu,
  }) =>
      RecuPaiement(
        chauffeur: chauffeur,
        vehicule: vehicule,
        lignes: lignes ??
            const [LigneRecu(libelle: 'Recette du 10/09/2026', montant: 15000)],
        modePaiement: mode,
        date: DateTime(2026, 9, 11),
        reference: reference,
        resteDu: resteDu,
      );

  test('le montant reçu vient en premier, en gras, avec le jour et le mode', () {
    final texte = composerRecu(recu());

    expect(texte, startsWith('✅ *Paiement reçu — TMK*'));
    expect(texte, contains('Bonjour Jean,'));
    expect(texte,
        contains('nous avons bien reçu *${montantRecu(15000)}* le 11/09/2026 en espèces.'));
    expect(texte, contains('• Recette du 10/09/2026'));
    expect(texte, endsWith('Merci et bonne route !'));
  });

  test('les montants sont en FCFA, la monnaie des billets', () {
    expect(montantRecu(15000), endsWith(' FCFA'));
    expect(composerRecu(recu()), isNot(contains('XOF')));
  });

  test('plusieurs créances soldées sont détaillées, montant par montant', () {
    final texte = composerRecu(recu(lignes: const [
      LigneRecu(libelle: 'Recette du 10/09/2026', montant: 15000),
      LigneRecu(libelle: 'Cotisation carburant du 10/09/2026', montant: 2000),
    ]));

    expect(texte, contains('*${montantRecu(17000)}* le 11/09/2026 en espèces :'));
    expect(texte, contains('• Recette du 10/09/2026 : ${montantRecu(15000)}'));
    expect(texte,
        contains('• Cotisation carburant du 10/09/2026 : ${montantRecu(2000)}'));
  });

  test('Mobile Money se lit dans la phrase', () {
    expect(composerRecu(recu(mode: 'Mobile Money')), contains('par Mobile Money'));
  });

  test('un solde nul dit au chauffeur qu\'il est à jour', () {
    final texte = composerRecu(recu(resteDu: 0));
    expect(texte, contains('Vous êtes à jour.'));
    expect(texte, isNot(contains('Reste à payer')));
  });

  test('un reste dû est annoncé en gras', () {
    expect(composerRecu(recu(resteDu: 5000)),
        contains('Reste à payer : *${montantRecu(5000)}*'));
  });

  // Une recette au réel n'a pas de dû d'avance : le reçu doit alors se taire
  // plutôt qu'annoncer un solde faux.
  test('un dû inconnu ne fait apparaître aucun solde', () {
    final texte = composerRecu(recu());
    expect(texte, isNot(contains('Reste à payer')));
    expect(texte, isNot(contains('à jour')));
  });

  test('les champs absents ne laissent ni libellé vide ni bloc vide', () {
    final texte = composerRecu(recu(chauffeur: null, vehicule: null, mode: null));

    expect(texte, contains('Bonjour,'));
    expect(texte, contains('nous avons bien reçu *${montantRecu(15000)}* le 11/09/2026.'));
    expect(texte, isNot(contains('Véhicule')));
    expect(texte, isNot(contains('Réf.')));
    expect(texte, isNot(contains('null')));
    expect(texte, isNot(contains('\n\n\n')));
  });

  test('véhicule et référence tiennent sur une ligne', () {
    expect(composerRecu(recu(reference: 'MP260911.1523.A1234')),
        contains('Véhicule 1234 AB 01 · Réf. MP260911.1523.A1234'));
  });

  test('joint au PDF, le message le signale ; seul, il n\'en dit rien', () {
    expect(composerRecu(recu(), avecPieceJointe: true),
        contains('📎 Le reçu détaillé vous est envoyé en PDF.'));
    expect(composerRecu(recu()), isNot(contains('PDF')));
  });
}
