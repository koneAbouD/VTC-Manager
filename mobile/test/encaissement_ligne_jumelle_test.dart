import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/widgets/encaissement_ligne_dialog.dart';

/// Recette de 15 000 restants, avec la cotisation du même jour (5 000) offerte
/// à cocher. Les deux callbacks consignent le montant qui leur est adressé.
class _Appels {
  final List<double> principal = [];
  final List<double> jumelle = [];
  String? erreurJumelle;
}

Future<bool?> _resultat = Future.value();

Future<void> _ouvrir(WidgetTester tester, _Appels appels) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              _resultat = showEncaissementLigneDialog(
                ctx,
                titre: 'Recette',
                sousTitre: 'AA-111 - Alpha',
                montantRestant: 15000,
                onEncaisser: (saisie) async {
                  appels.principal.add(saisie.montant);
                  return null;
                },
                jumelle: LigneJumelleEncaissement(
                  libelle: 'Encaisser aussi la cotisation du même jour',
                  titre: 'Épargne',
                  sousTitre: '01/09/2026',
                  montantRestant: 5000,
                  couleur: const Color(0xFFE65100),
                  icone: Icons.analytics_outlined,
                  onEncaisser: (saisie) async {
                    appels.jumelle.add(saisie.montant);
                    return appels.erreurJumelle;
                  },
                ),
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

Finder get _champMontant => find.byType(TextFormField).first;

Checkbox _caseJumelle(WidgetTester tester) =>
    tester.widget<Checkbox>(find.byType(Checkbox));

/// La feuille dépasse la hauteur de la surface de test : le bouton du bas doit
/// être amené à l'écran avant d'être touché.
Future<void> _tapBouton(WidgetTester tester, String label) async {
  final bouton = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(bouton);
  await tester.pumpAndSettle();
  await tester.tap(bouton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la ligne du même jour est proposée, décochée par défaut',
      (tester) async {
    await _ouvrir(tester, _Appels());

    expect(find.text('Encaisser aussi la cotisation du même jour'),
        findsOneWidget);
    expect(_caseJumelle(tester).value, isFalse);
    // Montant prérempli sur la seule ligne ouverte.
    expect(find.text('15 000'), findsOneWidget);
    expect(find.text('Répartition du montant'), findsNothing);
  });

  testWidgets('cocher la ligne jumelle porte le montant au total',
      (tester) async {
    await _ouvrir(tester, _Appels());

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(_caseJumelle(tester).value, isTrue);
    expect(find.text('20 000'), findsOneWidget);
    expect(find.text('Répartition du montant'), findsOneWidget);
  });

  testWidgets('un montant qui ne dépasse pas la ligne ouverte décoche la jumelle',
      (tester) async {
    await _ouvrir(tester, _Appels());

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(_caseJumelle(tester).value, isTrue);

    await tester.enterText(_champMontant, '15000');
    await tester.pump();
    expect(_caseJumelle(tester).value, isFalse);

    // Au-dessus du restant de la recette, la jumelle se recoche.
    await tester.enterText(_champMontant, '18000');
    await tester.pump();
    expect(_caseJumelle(tester).value, isTrue);
  });

  testWidgets('la soumission répartit le versement sur les deux lignes',
      (tester) async {
    final appels = _Appels();
    await _ouvrir(tester, appels);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await _tapBouton(tester, 'Encaisser');

    expect(appels.principal, [15000]);
    expect(appels.jumelle, [5000]);
    expect(await _resultat, isTrue);
  });

  testWidgets('jumelle en échec : le versement passé n\'est pas rejoué',
      (tester) async {
    final appels = _Appels()..erreurJumelle = 'Caisse clôturée';
    await _ouvrir(tester, appels);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await _tapBouton(tester, 'Encaisser');

    // La recette est passée, la cotisation non : la feuille reste ouverte, le
    // dit, et ne propose plus que de fermer.
    expect(appels.principal, [15000]);
    expect(appels.jumelle, [5000]);
    expect(find.textContaining('Caisse clôturée'), findsOneWidget);

    await _tapBouton(tester, 'Fermer');

    // Aucun second appel : le versement déjà enregistré n'est pas rejoué.
    expect(appels.principal, [15000]);
    expect(await _resultat, isTrue);
  });
}
