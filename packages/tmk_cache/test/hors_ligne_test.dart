import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_cache/tmk_cache.dart';

void main() {
  group('libellé du bandeau', () {
    final maintenant = DateTime(2026, 10, 26, 16, 0);

    test("aujourd'hui", () {
      expect(libelleHorsLigne(DateTime(2026, 10, 26, 14, 32), maintenant),
          'Hors connexion · données de 14:32');
    });

    test('hier', () {
      expect(libelleHorsLigne(DateTime(2026, 10, 25, 9, 5), maintenant),
          "Hors connexion · données d'hier à 09:05");
    });

    test('serveur en panne, internet joignable', () {
      expect(
          libelleHorsLigne(DateTime(2026, 10, 26, 14, 32), maintenant,
              cause: CauseIndisponibilite.serveur),
          'Serveur indisponible · données de 14:32');
    });

    test('cause inconnue : aucun des deux n\'est accusé', () {
      expect(
          libelleHorsLigne(DateTime(2026, 10, 26, 14, 32), maintenant,
              cause: CauseIndisponibilite.inconnue),
          'Serveur injoignable · données de 14:32');
    });

    test('accès coupé, Wi-Fi ou données sans internet', () {
      String libelle(CauseIndisponibilite c) =>
          libelleHorsLigne(DateTime(2026, 10, 26, 14, 32), maintenant, cause: c);
      expect(libelle(CauseIndisponibilite.reseauDesactive),
          'Wi-Fi et données coupés · données de 14:32');
      expect(libelle(CauseIndisponibilite.wifiSansInternet),
          'Wi-Fi sans internet · données de 14:32');
      expect(libelle(CauseIndisponibilite.donneesSansInternet),
          'Données mobiles sans internet · données de 14:32');
    });

    test('plus ancien', () {
      expect(libelleHorsLigne(DateTime(2026, 10, 3, 18, 0), maintenant),
          'Hors connexion · données du 03/10 à 18:00');
    });
  });

  group('état hors ligne', () {
    test('retient la plus ancienne donnée servie', () {
      final etat = EtatHorsLigne()
        ..donneesDuCache(DateTime(2026, 10, 26, 14))
        ..donneesDuCache(DateTime(2026, 10, 26, 9))
        ..donneesDuCache(DateTime(2026, 10, 26, 12));

      expect(etat.value, DateTime(2026, 10, 26, 9));
    });

    test('retient la cause de la dernière indisponibilité', () {
      final etat = EtatHorsLigne();
      var notifications = 0;
      etat.addListener(() => notifications++);

      etat.donneesDuCache(DateTime(2026, 10, 26, 9),
          cause: CauseIndisponibilite.reseau);
      etat.donneesDuCache(DateTime(2026, 10, 26, 12),
          cause: CauseIndisponibilite.serveur);

      expect(etat.cause, CauseIndisponibilite.serveur);
      expect(etat.value, DateTime(2026, 10, 26, 9));
      expect(notifications, 2, reason: 'le bandeau change de libellé');
    });

    test('le serveur qui répond efface le bandeau', () {
      final etat = EtatHorsLigne()..donneesDuCache(DateTime(2026, 10, 26));
      etat.serveurJoignable();

      expect(etat.value, isNull);
    });
  });

  testWidgets("le bandeau apparaît sans recréer l'application",
      (tester) async {
    final etat = EtatHorsLigne();
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => BandeauHorsLigne(
        etat: etat,
        fond: Colors.amber,
        texte: Colors.black,
        child: child!,
      ),
      home: const _Compteur(),
    ));
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    etat.donneesDuCache(DateTime.now(), cause: CauseIndisponibilite.reseau);
    await tester.pump();
    expect(find.textContaining('Hors connexion'), findsOneWidget);

    etat.donneesDuCache(DateTime.now(), cause: CauseIndisponibilite.serveur);
    await tester.pump();
    expect(find.textContaining('Serveur indisponible'), findsOneWidget);
    expect(find.text('1'), findsOneWidget, reason: "l'état de l'écran survit");

    etat.serveurJoignable();
    await tester.pump();
    expect(find.textContaining('données de'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  group("clé de cache d'une image", () {
    test('ignore la signature d\'une URL présignée', () {
      expect(
        cleImage('https://s3.tmk/vehicules/12.jpg'
            '?X-Amz-Algorithm=AWS4&X-Amz-Signature=abc&X-Amz-Date=1'),
        'https://s3.tmk/vehicules/12.jpg',
      );
    });

    test('garde un numéro de version', () {
      expect(cleImage('https://api.tmk/chauffeurs/3/photo?v=4'),
          'https://api.tmk/chauffeurs/3/photo?v=4');
    });

    test('une URL sans paramètre est sa propre clé', () {
      expect(cleImage('https://api.tmk/chauffeurs/3/photo'),
          'https://api.tmk/chauffeurs/3/photo');
    });
  });
}

class _Compteur extends StatefulWidget {
  const _Compteur();

  @override
  State<_Compteur> createState() => _CompteurState();
}

class _CompteurState extends State<_Compteur> {
  int _n = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => setState(() => _n++),
            child: Text('$_n'),
          ),
        ),
      );
}
