import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/widgets/app_header.dart';
import 'package:vtc_manager/core/widgets/header_tabs_pills.dart';

/// Monte les pastilles dans un en-tête réel, comme le HomeScreen.
Future<void> _pump(
  WidgetTester tester, {
  required List<String> labels,
  int index = 0,
  ValueChanged<int>? onSelected,
}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      appBar: AppHeader(
        title: '',
        showBack: false,
        center: HeaderTabsPills(
          labels: labels,
          index: index,
          onSelected: onSelected ?? (_) {},
        ),
      ),
      body: const SizedBox.shrink(),
    ),
  ));
}

void _rien(int _) {}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('des libellés courts tiennent sur la ligne, sans défilement',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, labels: const ['Un', 'Deux', 'Trois']);

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsNothing,
        reason: 'Pas besoin de faire défiler ce qui tient déjà.');
    expect(tester.getSize(find.byType(HeaderTabsPills)).width,
        lessThanOrEqualTo(390 - 32));
  });

  testWidgets('les pastilles adoptent toutes la largeur de la plus longue',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, labels: const ['Un', 'Deux', 'Trois']);

    final tailles = [
      for (final label in const ['Un', 'Deux', 'Trois'])
        tester.getSize(find
            .ancestor(
              of: find.text(label),
              matching: find.byType(AnimatedContainer),
            )
            .first)
    ];
    expect(tailles[1].width, tailles[0].width);
    expect(tailles[2].width, tailles[0].width);
    expect(tailles.every((t) => t.height == 34), isTrue);
  });

  testWidgets('l\'écart entre pastilles suit la largeur de l\'écran',
      (tester) async {
    Future<double> ecartPour(double largeurEcran) async {
      tester.view.physicalSize = Size(largeurEcran, 844);
      tester.view.devicePixelRatio = 1.0;
      await _pump(tester, labels: const ['Un', 'Deux', 'Trois']);
      return tester.getRect(find.text('Deux')).left -
          tester.getRect(find.text('Un')).right;
    }

    addTearDown(tester.view.reset);
    final surTelephone = await ecartPour(390);
    final surTablette = await ecartPour(820);

    expect(surTelephone, greaterThanOrEqualTo(14),
        reason: 'La rangée doit rester aérée même sur un téléphone.');
    expect(surTablette, greaterThan(surTelephone),
        reason: 'Plus l\'écran est large, plus les pastilles respirent.');
  });

  testWidgets('aucune largeur d\'écran ne fait déborder la rangée',
      (tester) async {
    addTearDown(tester.view.reset);

    // Balaie les largeurs entre un petit téléphone et une fenêtre de bureau :
    // le débordement se jouait à 3 px près sur certaines d'entre elles. Chaque
    // pas rejoue aussi les animations en cours — c'est là que se manifestait
    // l'interpolation entre une largeur imposée et une largeur libre.
    for (var largeur = 300.0; largeur <= 900; largeur += 7) {
      tester.view.physicalSize = Size(largeur, 844);
      tester.view.devicePixelRatio = 1.0;
      await _pump(tester, labels: const [
        'État de parc',
        'Véhicules',
        'Chauffeurs',
      ]);
      await tester.pump(const Duration(milliseconds: 90));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull,
          reason: 'Rendu fautif à ${largeur.round()} px de large.');
    }
  });

  testWidgets('supporte une largeur non bornée sans exception de layout',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Posé dans une Row (ou toute boîte sans largeur imposée), le widget reçoit
    // des contraintes horizontales infinies : aucun enfant ne peut y être
    // flexible.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            HeaderTabsPills(
              labels: ['Un', 'Deux', 'Trois'],
              index: 0,
              onSelected: _rien,
            ),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Trois'), findsOneWidget);
  });

  testWidgets('cinq onglets trop larges passent en rangée défilante',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pump(tester, labels: const [
      'Trésorerie',
      'Créances',
      'Partenaires',
      'Opérations',
      'Rapports',
    ]);

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    // Aucun libellé n'est rogné : les cinq restent dans l'arbre, entiers.
    expect(find.text('Rapports'), findsOneWidget);
    expect(tester.getSize(find.byType(HeaderTabsPills)).width,
        lessThanOrEqualTo(390 - 32));
  });

  testWidgets('la rangée défilante ramène l\'onglet actif sous les yeux',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const labels = [
      'Trésorerie',
      'Créances',
      'Partenaires',
      'Opérations',
      'Rapports',
    ];
    await _pump(tester, labels: labels);
    final ecran = tester.getSize(find.byType(MaterialApp)).width;
    expect(tester.getRect(find.text('Rapports')).left, greaterThan(ecran),
        reason: 'Le dernier onglet démarre hors champ.');

    // Sélection venue d'ailleurs (raccourci d'un autre écran), sans tap.
    await _pump(tester, labels: labels, index: 4);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('Rapports')).right, lessThanOrEqualTo(ecran));
  });

  testWidgets('un tap remonte l\'index de l\'onglet touché', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    int? touche;
    await _pump(tester,
        labels: const ['Un', 'Deux', 'Trois'],
        onSelected: (i) => touche = i);

    await tester.tap(find.text('Trois'));
    await tester.pumpAndSettle();

    expect(touche, 2);
  });
}
