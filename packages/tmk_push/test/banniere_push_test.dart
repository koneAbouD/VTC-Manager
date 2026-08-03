import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_push/tmk_push.dart';

void main() {
  /// Monte une application minimale et rend son overlay racine — celui-là même
  /// que le routeur de notifications utilise en production.
  Future<OverlayState> monterHote(WidgetTester tester) async {
    late OverlayState overlay;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        overlay = Overlay.of(context);
        return const Scaffold(body: SizedBox.expand());
      }),
    ));
    return overlay;
  }

  void afficher(
    OverlayState overlay, {
    String titre = 'Versement enregistré',
    String corps = 'Votre versement de recette du 03/08 a bien été enregistré.',
    VoidCallback? onTap,
  }) {
    afficherBannierePush(
      overlay,
      titre: titre,
      corps: corps,
      icone: Icons.payments_rounded,
      accent: Colors.green,
      onTap: onTap,
    );
  }

  testWidgets('affiche le texte de la notification', (tester) async {
    final overlay = await monterHote(tester);

    afficher(overlay);
    await tester.pumpAndSettle();

    expect(find.text('Versement enregistré'), findsOneWidget);
    expect(find.textContaining('03/08'), findsOneWidget);

    masquerBannierePush();
    await tester.pumpAndSettle();
  });

  testWidgets('se retire seule au bout de sa durée', (tester) async {
    final overlay = await monterHote(tester);

    afficher(overlay);
    await tester.pumpAndSettle();
    expect(find.text('Versement enregistré'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Versement enregistré'), findsNothing);
  });

  testWidgets('ouvre l\'écran visé au toucher, puis disparaît', (tester) async {
    final overlay = await monterHote(tester);
    var touchee = false;

    afficher(overlay, onTap: () => touchee = true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Versement enregistré'));
    await tester.pumpAndSettle();

    expect(touchee, isTrue);
    expect(find.text('Versement enregistré'), findsNothing);
  });

  testWidgets('une seconde notification remplace la première', (tester) async {
    final overlay = await monterHote(tester);

    afficher(overlay);
    await tester.pumpAndSettle();
    afficher(overlay, titre: 'Cotisation enregistrée', corps: 'Votre cotisation du 03/08…');
    await tester.pumpAndSettle();

    expect(find.text('Versement enregistré'), findsNothing);
    expect(find.text('Cotisation enregistrée'), findsOneWidget);

    masquerBannierePush();
    await tester.pumpAndSettle();
  });

  testWidgets('remplacer une bannière en train de s\'effacer ne lève pas',
      (tester) async {
    final overlay = await monterHote(tester);

    afficher(overlay);
    await tester.pumpAndSettle();

    // Fermeture par balayage vers le haut : l'animation de sortie démarre.
    await tester.fling(find.text('Versement enregistré'), const Offset(0, -60), 1200);
    await tester.pump(const Duration(milliseconds: 60));

    // Une notification arrive pile pendant cette sortie.
    afficher(overlay, titre: 'Cotisation enregistrée', corps: 'Votre cotisation du 03/08…');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cotisation enregistrée'), findsOneWidget);

    masquerBannierePush();
    await tester.pumpAndSettle();
  });

  testWidgets('le verrouillage la fait disparaître', (tester) async {
    final overlay = await monterHote(tester);

    afficher(overlay);
    await tester.pumpAndSettle();

    masquerBannierePush();
    await tester.pumpAndSettle();

    expect(find.text('Versement enregistré'), findsNothing);
  });
}
