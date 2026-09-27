import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/widgets/motif_annulation_dialog.dart';

/// Le champ du motif prend le focus à l'ouverture : le clavier ne laisse alors
/// qu'une petite hauteur au dialog, qui doit défiler plutôt que déborder.
void main() {
  testWidgets('clavier ouvert sur petit écran : aucun débordement',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    // Clavier de 300 px : il reste 340 px pour le dialog.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showSaisieAnnulationDialog(ctx,
                  optionLabel: 'Annuler aussi les cotisations du jour',
                  optionDetail: 'Recette et cotisations partent ensemble.'),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Confirmer'), findsOneWidget);
  });
}
