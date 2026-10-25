import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/contravention/domain/entities/contravention.dart';
import 'package:vtc_manager/features/contravention/presentation/widgets/contravention_card.dart';

Contravention _fake({
  String? statut,
  String? typeInfraction = 'Excès de vitesse',
}) =>
    Contravention(
      id: 42,
      dateInfraction: DateTime(2026, 7, 17),
      montant: 25000,
      statut: statut,
      vehiculeNom: 'AA-123-BB',
      chauffeurNom: 'Koné',
      typeInfraction: typeInfraction,
    );

Future<void> _monter(WidgetTester tester, Contravention c) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContraventionCard(
          contravention: c,
          selectable: false,
          selected: false,
          onSelectChanged: (_) {},
          onEdit: () {},
        ),
      ),
    ));

void main() {
  testWidgets('un tap sur la ligne coche la contravention', (tester) async {
    bool? received;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContraventionCard(
          contravention: _fake(statut: 'EN_ATTENTE'),
          selectable: true,
          selected: false,
          // Le tap ne coche qu'en mode sélection ; hors mode, il ouvre le
          // détail (voir la doc de ContraventionCard).
          selectionMode: true,
          onSelectChanged: (v) => received = v,
          onEdit: () => received = null,
        ),
      ),
    ));

    // Tap au centre de la carte (sur le contenu, pas la case).
    await tester.tap(find.text('AA-123-BB', findRichText: true));
    await tester.pump();

    expect(received, isTrue,
        reason: 'Le tap sur la ligne doit demander la coche (true).');
  });

  testWidgets('une ligne déjà reversée ouvre le détail au tap (non cochable)',
      (tester) async {
    var edited = false;
    var selectChanged = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContraventionCard(
          contravention: _fake(statut: 'REVERSE'),
          selectable: false,
          selected: false,
          onSelectChanged: (_) => selectChanged = true,
          onEdit: () => edited = true,
        ),
      ),
    ));

    await tester.tap(find.text('AA-123-BB', findRichText: true));
    await tester.pump();

    expect(selectChanged, isFalse);
    expect(edited, isTrue);
  });

  group("pastille du type d'infraction", () {
    testWidgets('type inconnu : aucune pastille « Contravention »',
        (tester) async {
      for (final type in [null, '', '  ']) {
        await _monter(tester, _fake(typeInfraction: type));
        expect(find.text('Contravention'), findsNothing,
            reason: 'type ${type == null ? 'absent' : 'vide'}');
      }
    });

    testWidgets('type connu : la pastille le montre', (tester) async {
      await _monter(tester, _fake());
      expect(find.text('Excès de vitesse'), findsOneWidget);
    });
  });
}
