import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/models/encaissement_lot.dart';
import 'package:vtc_manager/core/widgets/encaissement_lot_dialog.dart';

/// Trois journées de recette encore ouvertes, sélectionnées depuis la liste.
const _lignes = [
  LigneLotEncaissable(
      id: 1,
      titre: 'AA-111 - Alpha',
      sousTitre: 'Recette du 01/09/2026',
      restant: 15000),
  LigneLotEncaissable(
      id: 2,
      titre: 'AA-111 - Alpha',
      sousTitre: 'Recette du 02/09/2026',
      restant: 10000),
  LigneLotEncaissable(
      id: 3,
      titre: 'BB-222 - Bravo',
      sousTitre: 'Recette du 02/09/2026',
      restant: 5000),
];

/// Ce que le faux serveur a reçu, et ce qu'il renvoie.
class _Serveur {
  SaisieLot? recu;
  IssueLot reponse = const IssueLot(reussies: {1, 2, 3});

  Future<IssueLot> encaisser(SaisieLot saisie) async {
    recu = saisie;
    return reponse;
  }
}

Future<bool?> _resultat = Future.value();

Future<void> _ouvrir(WidgetTester tester, _Serveur serveur) async {
  _resultat = Future.value();
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              _resultat = showEncaissementLotDialog(
                ctx,
                titre: 'Encaisser 3 recette(s)',
                lignes: _lignes,
                onEncaisser: serveur.encaisser,
              );
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  ));

  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

/// Les montants formatés portent les espaces insécables du français : on les
/// ramène à l'espace ordinaire avant de comparer.
String _normalise(String texte) =>
    texte.replaceAll(RegExp(r'[\u00A0\u202F\u2009]'), ' ');

Finder _montantAffiche(String attendu) => find.byWidgetPredicate((w) =>
    w is Text && w.data != null && _normalise(w.data!) == attendu);

Finder _texteContenant(String extrait) => find.byWidgetPredicate((w) =>
    w is Text && w.data != null && _normalise(w.data!).contains(extrait));

/// Les champs montant, dans l'ordre d'affichage des lignes.
Finder _champMontant(int index) => find.byType(TextFormField).at(index);

/// Une seule journée, dont la cotisation du même jour est encore ouverte.
Future<void> _ouvrirAvecJumelle(WidgetTester tester, _Serveur serveur) async {
  _resultat = Future.value();
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              _resultat = showEncaissementLotDialog(
                ctx,
                titre: 'Encaisser 1 recette(s)',
                lignes: const [
                  LigneLotEncaissable(
                    id: 1,
                    titre: 'AA-111 - Alpha',
                    sousTitre: 'Recette du 01/09/2026',
                    restant: 15000,
                    jumelle:
                        JumelleLot(id: 91, libelle: 'Épargne', restant: 5000),
                  ),
                ],
                onEncaisser: serveur.encaisser,
              );
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  ));

  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

Future<void> _tapBouton(WidgetTester tester, String label) async {
  final bouton = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(bouton);
  await tester.pumpAndSettle();
  await tester.tap(bouton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('chaque ligne arrive avec son reste dû, et le total les somme',
      (tester) async {
    await _ouvrir(tester, _Serveur());

    // Les champs affichent les séparateurs de milliers dès l'ouverture.
    expect(find.text('15 000'), findsOneWidget);
    expect(find.text('10 000'), findsOneWidget);
    expect(find.text('5 000'), findsOneWidget);
    // 15 000 + 10 000 + 5 000
    expect(_montantAffiche('30 000 XOF'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Encaisser (3)'), findsOneWidget);
  });

  testWidgets('un montant réduit ne change que sa ligne', (tester) async {
    final serveur = _Serveur();
    await _ouvrir(tester, serveur);

    await tester.enterText(_champMontant(0), '8000');
    await tester.pump();

    expect(_montantAffiche('23 000 XOF'), findsOneWidget);

    await _tapBouton(tester, 'Encaisser (3)');

    expect(serveur.recu!.lignes.map((l) => l.montant).toList(),
        [8000.0, 10000.0, 5000.0]);
    expect(await _resultat, isTrue);
  });

  testWidgets('un montant à zéro écarte la ligne du lot', (tester) async {
    final serveur = _Serveur()..reponse = const IssueLot(reussies: {1, 3});
    await _ouvrir(tester, serveur);

    await tester.enterText(_champMontant(1), '0');
    await tester.pump();

    expect(_montantAffiche('20 000 XOF'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Encaisser (2)'), findsOneWidget);

    await _tapBouton(tester, 'Encaisser (2)');
    expect(serveur.recu!.lignes.map((l) => l.ligneId).toList(), [1, 3]);
  });

  testWidgets('un montant au-dessus du reste dû est refusé à la saisie',
      (tester) async {
    final serveur = _Serveur();
    await _ouvrir(tester, serveur);

    await tester.enterText(_champMontant(2), '9000');
    await tester.pump();

    await _tapBouton(tester, 'Encaisser (3)');

    // Le formulaire ne part pas : la ligne 3 ne peut pas recevoir plus que ses
    // 5 000 restants.
    expect(serveur.recu, isNull);
    expect(_montantAffiche('Max 5 000 XOF'), findsOneWidget);
  });

  testWidgets('une ligne refusée reste à l\'écran avec son motif',
      (tester) async {
    final serveur = _Serveur()
      ..reponse = const IssueLot(
        reussies: {1, 3},
        echecs: {2: 'Impossible d\'écrire au 2026-09-02 : la période comptable est clôturée'},
      );
    await _ouvrir(tester, serveur);

    await _tapBouton(tester, 'Encaisser (3)');

    // Les deux lignes passées ont quitté la feuille, la refusée porte son motif.
    expect(_texteContenant('Recette du 01/09/2026'), findsNothing);
    expect(_texteContenant('période comptable est clôturée'), findsOneWidget);
    expect(_texteContenant('2 ligne(s) encaissée(s)'), findsOneWidget);

    // Fermer rend « true » : la liste appelante doit se rafraîchir.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Fermer'));
    await tester.pumpAndSettle();
    expect(await _resultat, isTrue);
  });

  testWidgets('une panne réseau laisse la feuille ouverte, rien n\'est perdu',
      (tester) async {
    final serveur = _Serveur()
      ..reponse = IssueLot.erreur('Connexion au serveur impossible');
    await _ouvrir(tester, serveur);

    await _tapBouton(tester, 'Encaisser (3)');

    expect(find.textContaining('Connexion au serveur impossible'),
        findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Encaisser (3)'), findsOneWidget);
  });

  testWidgets('la limite d\'une ligne inclut la créance du même jour',
      (tester) async {
    final serveur = _Serveur();
    await _ouvrirAvecJumelle(tester, serveur);

    // Recette 15 000 + cotisation 5 000 : la ligne accepte jusqu'à 20 000, et
    // c'est ce total qui est prérempli.
    expect(_texteContenant('+ Épargne · reste 5 000 XOF'), findsOneWidget);
    expect(find.text('20 000'), findsOneWidget);
    expect(_montantAffiche('20 000 XOF'), findsOneWidget);
    // La répartition est visible d'emblée, sans rien saisir.
    expect(
        _texteContenant(
            'Recette du 01/09/2026 : 15 000 XOF · Épargne : 5 000 XOF'),
        findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '18000');
    await tester.pumpAndSettle();

    // Le guichet voit où va l'argent avant d'envoyer.
    expect(
        _texteContenant(
            'Recette du 01/09/2026 : 15 000 XOF · Épargne : 3 000 XOF'),
        findsOneWidget);

    // Au-delà des deux créances, la saisie est refusée.
    await tester.enterText(find.byType(TextFormField).first, '21000');
    await tester.pumpAndSettle();
    expect(_montantAffiche('Max 20 000 XOF'), findsOneWidget);
  });

  test('le verdict du serveur se traduit en état de feuille', () {
    final issue = IssueLot.depuis(const ResultatEncaissementLot(
      reussis: 1,
      echecs: 1,
      resultats: [
        ResultatLigneLot(ligneId: 1, succes: true, encaissementId: 9),
        ResultatLigneLot(ligneId: 2, succes: false, message: 'Caisse clôturée'),
      ],
    ));

    expect(issue.reussies, {1});
    expect(issue.echecs, {2: 'Caisse clôturée'});
    expect(issue.erreurGlobale, isNull);
  });
}
