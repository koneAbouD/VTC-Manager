import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/contravention/domain/entities/contravention.dart';
import 'package:vtc_manager/features/contravention/presentation/widgets/contravention_card.dart';

Contravention _fake({String? statut}) => Contravention(
      id: 42,
      dateInfraction: DateTime(2026, 7, 17),
      montant: 25000,
      statut: statut,
      vehiculeNom: 'AA-123-BB',
      chauffeurNom: 'Koné',
      typeInfraction: 'Excès de vitesse',
    );

void main() {
  testWidgets('un tap sur la ligne coche la contravention', (tester) async {
    bool? received;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContraventionCard(
          contravention: _fake(statut: 'EN_ATTENTE'),
          selectable: true,
          selected: false,
          onSelectChanged: (v) => received = v,
          onEdit: () => received = null,
        ),
      ),
    ));

    // Tap au centre de la carte (sur le contenu, pas la case).
    await tester.tap(find.text('Excès de vitesse'));
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

    await tester.tap(find.text('Excès de vitesse'));
    await tester.pump();

    expect(selectChanged, isFalse);
    expect(edited, isTrue);
  });
}
