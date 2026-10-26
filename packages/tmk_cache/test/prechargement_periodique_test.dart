import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_cache/tmk_cache.dart';

void main() {
  late int lancements;

  Future<void> monter(WidgetTester tester) async {
    lancements = 0;
    await tester.pumpWidget(PrechargementPeriodique(
      precharger: () async => lancements++,
      delai: const Duration(seconds: 3),
      intervalle: const Duration(minutes: 15),
      child: const SizedBox(),
    ));
  }

  void retourPremierPlan(WidgetTester tester) => tester.binding
      .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  testWidgets("part peu après l'ouverture, pas avant", (tester) async {
    await monter(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(lancements, 0, reason: "le premier écran charge d'abord");

    await tester.pump(const Duration(seconds: 1));
    expect(lancements, 1);
  });

  testWidgets('au retour au premier plan, au plus une fois par intervalle',
      (tester) async {
    await monter(tester);
    await tester.pump(const Duration(seconds: 3));

    retourPremierPlan(tester);
    await tester.pump();
    expect(lancements, 1, reason: 'lancé il y a quelques secondes');
  });

  testWidgets("démonté avant le départ : rien ne part", (tester) async {
    await monter(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));

    expect(lancements, 0);
  });
}
