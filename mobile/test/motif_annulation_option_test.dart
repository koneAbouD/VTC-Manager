import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/widgets/motif_annulation_dialog.dart';

/// La case du dialog d'annulation porte une seconde annulation (les cotisations
/// de la journée, depuis une recette) : ce qu'elle vaut à la validation décide
/// du sort de lignes qui ne sont pas à l'écran.

/// Ce que le dialog a rendu, une fois refermé.
class _Sortie {
  SaisieAnnulation? saisie;
}

Future<_Sortie> _ouvrir(
  WidgetTester tester, {
  String? optionLabel,
  bool optionInitiale = true,
}) async {
  final sortie = _Sortie();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => sortie.saisie = await showSaisieAnnulationDialog(
            context,
            optionLabel: optionLabel,
            optionDetail: 'Entretien · Assurance',
            optionInitiale: optionInitiale,
          ),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return sortie;
}

Future<SaisieAnnulation?> _valider(WidgetTester tester, _Sortie sortie) async {
  await tester.tap(find.text('Confirmer'));
  await tester.pumpAndSettle();
  return sortie.saisie;
}

void main() {
  testWidgets('sans option, le dialog ne montre aucune case',
      (tester) async {
    final saisie = await _ouvrir(tester);

    expect(find.byType(Checkbox), findsNothing);

    await tester.enterText(find.byType(TextField), 'erreur de saisie');
    await tester.pump();
    final resultat = await _valider(tester, saisie);

    expect(resultat!.motif, 'erreur de saisie');
    expect(resultat.optionCochee, isFalse);
  });

  testWidgets('la case proposée est cochée par défaut et validée telle quelle',
      (tester) async {
    final saisie =
        await _ouvrir(tester, optionLabel: 'Annuler aussi les 2 cotisations');

    expect(find.text('Annuler aussi les 2 cotisations'), findsOneWidget);
    expect(find.text('Entretien · Assurance'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'véhicule non sorti');
    await tester.pump();
    final resultat = await _valider(tester, saisie);

    expect(resultat!.motif, 'véhicule non sorti');
    expect(resultat.optionCochee, isTrue);
  });

  testWidgets('décocher la case laisse les cotisations dues', (tester) async {
    final saisie =
        await _ouvrir(tester, optionLabel: 'Annuler aussi la cotisation');

    await tester.enterText(find.byType(TextField), 'montant erroné');
    await tester.pump();
    // Toute la carte est cliquable : c'est ce que touche l'utilisateur.
    await tester.tap(find.text('Annuler aussi la cotisation'));
    await tester.pump();
    final resultat = await _valider(tester, saisie);

    expect(resultat!.optionCochee, isFalse);
  });

  testWidgets('le motif reste obligatoire, la case n\'y change rien',
      (tester) async {
    await _ouvrir(tester, optionLabel: 'Annuler aussi la cotisation');

    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    // Le dialog est toujours là : rien n'a été validé.
    expect(find.text('Confirmer'), findsOneWidget);
  });

  testWidgets('une case décochée d\'avance le reste', (tester) async {
    final saisie = await _ouvrir(tester,
        optionLabel: 'Annuler aussi la cotisation', optionInitiale: false);

    await tester.enterText(find.byType(TextField), 'doublon');
    await tester.pump();
    final resultat = await _valider(tester, saisie);

    expect(resultat!.optionCochee, isFalse);
  });
}
