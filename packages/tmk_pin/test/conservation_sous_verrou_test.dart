import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_pin/tmk_pin.dart';

/// Accueil à onglets : son état dit si l'écran a été conservé ou reconstruit.
class _Accueil extends StatefulWidget {
  const _Accueil({super.key});

  @override
  State<_Accueil> createState() => _AccueilState();
}

class _AccueilState extends State<_Accueil> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            Text('Onglet $_onglet'),
            TextButton(
              onPressed: () => setState(() => _onglet++),
              child: const Text('Onglet suivant'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Column(
                      children: [Text('Détail'), TextField()],
                    ),
                  ),
                ),
              ),
              child: const Text('Ouvrir le détail'),
            ),
          ],
        ),
      );
}

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late ValueNotifier<EtatSession> etat;
  late DateTime maintenant;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
    etat = ValueNotifier(EtatSession.ouverte);
    maintenant = DateTime(2026, 10, 29, 9);
  });

  Widget app() => ValueListenableBuilder<EtatSession>(
        valueListenable: etat,
        builder: (_, e, __) => ConservationSousVerrou(
          etat: e,
          navigatorKey: navigatorKey,
          horloge: () => maintenant,
          builder: (_, conservation) => MaterialApp(
            navigatorKey: navigatorKey,
            builder: (_, child) => CouvertureVerrou(
              conservation: conservation,
              ecranVerrou: const Scaffold(body: Text('Écran de code')),
              child: child!,
            ),
            home: switch (e) {
              EtatSession.ouverte => _Accueil(key: conservation.cleAccueil),
              EtatSession.verrouillee when conservation.couverte =>
                _Accueil(key: conservation.cleAccueil),
              EtatSession.verrouillee =>
                const Scaffold(body: Text('Écran de code')),
              _ => const Scaffold(body: Text('Connexion')),
            },
          ),
        ),
      );

  /// Ouvre une page par-dessus l'accueil, sur le deuxième onglet, avec une
  /// saisie en cours.
  Future<void> ouvrirDetail(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Onglet suivant'));
    await tester.pump();
    await tester.tap(find.text('Ouvrir le détail'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'brouillon');
  }

  Future<void> passerA(WidgetTester tester, EtatSession nouvel) async {
    etat.value = nouvel;
    await tester.pump();
    await tester.pump();
  }

  testWidgets('verrouillée, l\'application cache la page sous l\'écran de code',
      (tester) async {
    await ouvrirDetail(tester);

    await passerA(tester, EtatSession.verrouillee);

    expect(find.text('Écran de code'), findsOneWidget);
    expect(find.text('Détail'), findsNothing);
    expect(find.text('brouillon'), findsNothing);
    // Aucune saisie ne parvient à la page cachée.
    expect(FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()));
  });

  testWidgets('déverrouillée avant 10 min, elle revient sur la même page',
      (tester) async {
    await ouvrirDetail(tester);
    await passerA(tester, EtatSession.verrouillee);

    maintenant = maintenant.add(const Duration(minutes: 9, seconds: 59));
    await passerA(tester, EtatSession.ouverte);

    expect(find.text('Écran de code'), findsNothing);
    expect(find.text('Détail'), findsOneWidget);
    expect(find.text('brouillon'), findsOneWidget);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Onglet 1'), findsOneWidget);
  });

  testWidgets(
      'déverrouillée après 10 min d\'application suspendue, elle repart de '
      'l\'accueil', (tester) async {
    await ouvrirDetail(tester);
    await passerA(tester, EtatSession.verrouillee);

    // Le minuteur n'a pas sonné (application suspendue), l'horloge si.
    maintenant = maintenant.add(const Duration(minutes: 10));
    await passerA(tester, EtatSession.ouverte);
    await tester.pumpAndSettle();

    expect(find.text('Écran de code'), findsNothing);
    expect(find.text('Détail'), findsNothing);
    expect(find.text('Onglet 0'), findsOneWidget);
  });

  testWidgets(
      'au bout de 10 min sous le verrou, la page est abandonnée sans toucher '
      'à l\'écran de code', (tester) async {
    await ouvrirDetail(tester);
    await passerA(tester, EtatSession.verrouillee);

    await tester.pump(ConservationSousVerrou.delaiConservation);
    expect(find.text('Écran de code'), findsOneWidget);

    await passerA(tester, EtatSession.ouverte);
    await tester.pumpAndSettle();

    expect(find.text('Détail'), findsNothing);
    expect(find.text('Onglet 0'), findsOneWidget);
  });

  testWidgets(
      'sous le verrou, le retour arrière quitte l\'application sans dépiler '
      'la page cachée', (tester) async {
    final appels = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        appels.add(call.method);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await ouvrirDetail(tester);
    await passerA(tester, EtatSession.verrouillee);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(appels, contains('SystemNavigator.pop'));

    await passerA(tester, EtatSession.ouverte);
    expect(find.text('Détail'), findsOneWidget);
  });

  testWidgets('déconnectée depuis l\'écran de code, la page est abandonnée',
      (tester) async {
    await ouvrirDetail(tester);
    await passerA(tester, EtatSession.verrouillee);

    await passerA(tester, EtatSession.fermee);
    await tester.pumpAndSettle();
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Écran de code'), findsNothing);

    await passerA(tester, EtatSession.ouverte);
    await tester.pumpAndSettle();
    expect(find.text('Détail'), findsNothing);
    expect(find.text('Onglet 0'), findsOneWidget);
  });

  testWidgets('verrouillée au démarrage, rien n\'est conservé', (tester) async {
    etat.value = EtatSession.verrouillee;
    await tester.pumpWidget(app());

    expect(find.text('Écran de code'), findsOneWidget);

    await passerA(tester, EtatSession.ouverte);
    expect(find.text('Onglet 0'), findsOneWidget);
  });
}
