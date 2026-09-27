import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/partenaire/domain/entities/facture_partenaire.dart';
import 'package:vtc_manager/features/partenaire/presentation/widgets/facture_dialogs.dart';

/// Feuille de règlement d'une facture partenaire, clavier ouvert sur un écran
/// large et bas (Fold déplié, paysage) : elle doit défiler, pas déborder.
void main() {
  testWidgets('clavier ouvert : la feuille de règlement ne déborde pas',
      (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.reset);

    final facture = FacturePartenaire(
      id: 1,
      reference: 'FRN-1',
      partenaireNom: 'Garage Central',
      dateFacture: DateTime(2026, 9, 1),
      dateEcheance: DateTime(2026, 9, 30),
      montant: 50000,
      montantPaye: 10000,
      restantDu: 40000,
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Consumer(
          builder: (ctx, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showReglementFactureDialog(ctx, ref, facture),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Régler'), findsWidgets);
  });
}
