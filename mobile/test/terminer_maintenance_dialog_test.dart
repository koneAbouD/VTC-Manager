import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:vtc_manager/features/maintenance/presentation/widgets/terminer_maintenance_dialog.dart';
import 'package:vtc_manager/features/operation_financiere/domain/entities/element_maintenance.dart';

/// Ouvre la popup et rend le choix rapporté par l'appelant.
Future<ChoixCloture?> _ouvrir(
  WidgetTester tester, {
  required String titre,
  String validerLabel = 'Confirmer',
  double? coutInitial,
  String? partenaireNom,
  List<ElementMaintenance> elements = const [],
}) async {
  ChoixCloture? choix;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            choix = await showTerminerMaintenanceDialog(
              context,
              titre: titre,
              message: 'Renseignez le coût réel des travaux.',
              typeLabel: 'Vidange',
              partenaireNom: partenaireNom,
              elements: elements,
              coutInitial: coutInitial,
              validerLabel: validerLabel,
            );
          },
          child: const Text('ouvrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return choix;
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR', null));

  testWidgets('le titre et le libellé de validation viennent de l\'appelant',
      (tester) async {
    // La même popup sert à clôturer une intervention planifiée et à enregistrer
    // une intervention déjà faite : seul son intitulé dit laquelle.
    await _ouvrir(tester,
        titre: 'Intervention déjà réalisée', validerLabel: 'Enregistrer');

    expect(find.text('Intervention déjà réalisée'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('Terminer la maintenance'), findsNothing);
  });

  testWidgets('le coût des lignes est proposé, et reste modifiable',
      (tester) async {
    await _ouvrir(tester, titre: 'Intervention déjà réalisée', coutInitial: 25000);

    expect(find.widgetWithText(TextField, '25000'), findsOneWidget);
  });

  testWidgets('confirmer rapporte le coût saisi, réglé au comptant',
      (tester) async {
    ChoixCloture? choix;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              choix = await showTerminerMaintenanceDialog(
                context,
                titre: 'Terminer la maintenance',
                message: 'Renseignez le coût réel des travaux.',
                typeLabel: 'Vidange',
                validerLabel: 'Confirmer',
              );
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '31500');
    await tester.pump();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    expect(choix, isNotNull);
    expect(choix!.cout, 31500);
    expect(choix!.aCredit, isFalse);
    expect(choix!.echeance, isNull);
  });

  testWidgets('« À payer » annonce la dette à naître et remonte son échéance',
      (tester) async {
    ChoixCloture? choix;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              choix = await showTerminerMaintenanceDialog(
                context,
                titre: 'Intervention déjà réalisée',
                message: 'Renseignez le coût réel des travaux.',
                typeLabel: 'Vidange',
                partenaireNom: 'Garage Koné',
                elements: const [
                  ElementMaintenance(libelle: 'Huile', montant: 20000),
                ],
                coutInitial: 20000,
                validerLabel: 'Enregistrer',
              );
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('À payer'));
    await tester.pumpAndSettle();

    // On ne valide pas une dette sans savoir envers qui.
    expect(find.text('Une dette sera créée :'), findsOneWidget);
    expect(find.text('Garage Koné'), findsOneWidget);

    await tester.tap(find.text('Créer la dette'));
    await tester.pumpAndSettle();

    expect(choix!.aCredit, isTrue);
    expect(choix!.echeance, isNotNull);
    expect(choix!.cout, 20000);
  });

  testWidgets('sans coût saisi, la validation reste fermée', (tester) async {
    await _ouvrir(tester, titre: 'Terminer la maintenance');

    final bouton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmer'));
    expect(bouton.onPressed, isNull);
  });
}
