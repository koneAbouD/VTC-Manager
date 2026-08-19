import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/tresorerie/presentation/widgets/cloture_refusee_dialog.dart';

Future<void> _monter(WidgetTester tester, ClotureRefuseeDialog dialogue) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: dialogue)));
}

void main() {
  testWidgets('tous les obstacles sont affichés, pas seulement le résumé',
      (tester) async {
    // Les révéler un par un obligeait à relancer la clôture autant de fois
    // qu'il restait de comptages à faire.
    await _monter(
      tester,
      const ClotureRefuseeDialog(
        mois: 'Juillet 2026',
        message: '3 points restent à régler avant de figer le mois.',
        obstacles: [
          'Le compte « Caisse espèces » n\'a fait l\'objet d\'aucun comptage.',
          'Le compte « Orange Money » n\'a fait l\'objet d\'aucun relevé.',
          'L\'écart constaté au comptage du 2026-07-12 attend son imputation.',
        ],
        consigne: 'Comptez les comptes listés, puis relancez la clôture.',
        actionLabel: 'Ouvrir la trésorerie',
      ),
    );

    expect(find.textContaining('3 points'), findsOneWidget);
    expect(find.textContaining('Caisse espèces'), findsOneWidget);
    expect(find.textContaining('Orange Money'), findsOneWidget);
    expect(find.textContaining('attend son imputation'), findsOneWidget);
    expect(find.textContaining('Juillet 2026'), findsOneWidget);
  });

  testWidgets('un obstacle unique n\'est pas répété sous le message',
      (tester) async {
    const seul = 'L\'écart du 2026-07-12 sur « Caisse » attend son imputation.';
    await _monter(
      tester,
      const ClotureRefuseeDialog(
        mois: 'Juillet 2026',
        message: seul,
        obstacles: [seul],
        consigne: 'Tranchez chaque écart, puis relancez la clôture.',
        actionLabel: 'Trancher les écarts',
      ),
    );

    // Le message reprend déjà l'obstacle : en faire une puce ferait doublon.
    expect(find.textContaining('attend son imputation'), findsOneWidget);
  });

  testWidgets('le bouton d\'action renvoie true, « Fermer » renvoie false',
      (tester) async {
    bool? resultat;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultat = await showDialog<bool>(
                context: context,
                builder: (_) => const ClotureRefuseeDialog(
                  mois: 'Juillet 2026',
                  message: 'La caisse n\'a pas été comptée.',
                  obstacles: [],
                  consigne: 'Comptez la caisse, puis relancez la clôture.',
                  actionLabel: 'Ouvrir la trésorerie',
                ),
              );
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir la trésorerie'));
    await tester.pumpAndSettle();
    expect(resultat, isTrue, reason: 'L\'action doit être demandée.');

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(resultat, isFalse, reason: 'Fermer ne doit rien déclencher.');
  });

  testWidgets('sans action possible, seul « Fermer » est proposé',
      (tester) async {
    await _monter(
      tester,
      const ClotureRefuseeDialog(
        mois: 'Août 2026',
        message: 'Seul un mois strictement passé peut être clôturé',
        obstacles: [],
        consigne: 'Attendez la fin du mois.',
        actionLabel: null,
      ),
    );

    expect(find.text('Fermer'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
