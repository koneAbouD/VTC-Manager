import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/widgets/app_header.dart';
import 'package:vtc_manager/screens/fleet/fleet_tabs_pills.dart';
import 'package:vtc_manager/screens/home_nav_provider.dart';

/// Monte les pastilles d'onglets dans un en-tête réel, comme le HomeScreen.
Future<ProviderContainer> _pumpPills(WidgetTester tester,
    {Widget? leading}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        appBar: AppHeader(
          title: '',
          showBack: false,
          leading: leading,
          center: const FleetTabsPills(),
        ),
        body: const SizedBox.shrink(),
      ),
    ),
  ));
  return container;
}

void main() {
  setUp(() {
    // Largeur d'un téléphone courant : les trois pastilles doivent y tenir.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('les trois onglets se posent dans l\'en-tête sans déborder',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpPills(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('État de parc'), findsOneWidget);
    expect(find.text('Véhicules'), findsOneWidget);
    expect(find.text('Chauffeurs'), findsOneWidget);

    final pastilles = tester.getSize(find.byType(FleetTabsPills));
    expect(pastilles.width, lessThanOrEqualTo(390 - 32),
        reason: 'L\'en-tête réserve 16 px de marge de chaque côté.');
  });

  testWidgets('un écran étroit resserre les pastilles au lieu de déborder',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpPills(tester);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FleetTabsPills)).width,
        lessThanOrEqualTo(320 - 32));
  });

  testWidgets('un tap sur une pastille change l\'onglet actif', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await _pumpPills(tester);
    expect(container.read(fleetTabIndexProvider), FleetTab.etatParc);

    // La police de test étant bien plus large que la vraie, la rangée peut
    // passer en mode défilant ici : on amène la pastille sous les yeux comme
    // le ferait l'utilisateur.
    await tester.ensureVisible(find.text('Chauffeurs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chauffeurs'));
    await tester.pumpAndSettle();

    expect(container.read(fleetTabIndexProvider), FleetTab.chauffeurs);
  });

  testWidgets('les pastilles cohabitent avec un bouton d\'en-tête',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpPills(tester,
        leading: AppHeaderAction(icon: Icons.menu_rounded, onTap: () {}));

    expect(tester.takeException(), isNull);
    final bouton = tester.getRect(find.byType(AppHeaderAction));
    final pastilles = tester.getRect(find.byType(FleetTabsPills));
    expect(pastilles.left, greaterThanOrEqualTo(bouton.right),
        reason: 'Aucun chevauchement avec le bouton de gauche.');
  });
}
