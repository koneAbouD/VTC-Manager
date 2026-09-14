import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/widgets/encaissement_ligne_dialog.dart';

/// Recette de 15 000 restants, avec la cotisation du même jour (5 000) offerte
/// à cocher. La ligne seule part par `onEncaisser` ; avec sa jumelle, les deux
/// partent ensemble par `encaisserEnsemble` — un billet, un appel.
class _Appels {
  final List<double> principal = [];
  final List<(double?, double)> ensemble = [];
  String? erreurEnsemble;
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
                  encaisserEnsemble: (principale, jumelle) async {
                    appels.ensemble.add((principale?.montant, jumelle.montant));
                    return appels.erreurEnsemble;
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

  testWidgets('avec la jumelle, le versement part en un seul appel réparti',
      (tester) async {
    final appels = _Appels();
    await _ouvrir(tester, appels);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await _tapBouton(tester, 'Encaisser');

    // Un billet, un appel : les deux parts voyagent ensemble.
    expect(appels.ensemble, [(15000.0, 5000.0)]);
    expect(appels.principal, isEmpty);
    expect(await _resultat, isTrue);
  });

  testWidgets('sans la jumelle, la ligne ouverte part seule', (tester) async {
    final appels = _Appels();
    await _ouvrir(tester, appels);

    await _tapBouton(tester, 'Encaisser');

    expect(appels.principal, [15000]);
    expect(appels.ensemble, isEmpty);
    expect(await _resultat, isTrue);
  });

  testWidgets(
      'versement refusé : rien n\'est enregistré, la feuille reste ouverte '
      'et le même versement peut repartir', (tester) async {
    final appels = _Appels()..erreurEnsemble = 'Caisse clôturée';
    await _ouvrir(tester, appels);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await _tapBouton(tester, 'Encaisser');

    // Tout ou rien : le refus est affiché, et le bouton reste « Encaisser » —
    // aucune moitié n'étant passée, il n'y a rien à protéger d'un rejeu.
    expect(find.textContaining('Caisse clôturée'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Encaisser'), findsOneWidget);

    appels.erreurEnsemble = null;
    await _tapBouton(tester, 'Encaisser');

    expect(appels.ensemble, [(15000.0, 5000.0), (15000.0, 5000.0)]);
    expect(await _resultat, isTrue);
  });
}
