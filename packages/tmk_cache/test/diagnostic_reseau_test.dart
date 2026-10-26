import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_cache/tmk_cache.dart';

/// Pas d'internet ou serveur en panne : l'utilisateur ne fait pas la même
/// chose dans les deux cas (vérifier son Wi-Fi, ou patienter).
void main() {
  SocketException systeme(String message, int code) =>
      SocketException(message, osError: OSError(message, code));

  group('sans sonde : l\'erreur suffit', () {
    late int sondes;
    late DiagnosticReseau diagnostic;

    setUp(() {
      sondes = 0;
      diagnostic = DiagnosticReseau(sonde: () async {
        sondes++;
        return true;
      });
    });

    for (final code in [61, 111, 10061]) {
      test('connexion refusée ($code) : le serveur est arrêté', () async {
        expect(await diagnostic.causeDe(systeme('Connection refused', code)),
            CauseIndisponibilite.serveur);
        expect(sondes, 0);
      });
    }

    for (final code in [51, 101, 10051]) {
      test('réseau injoignable ($code) : pas d\'internet', () async {
        expect(await diagnostic.causeDe(systeme('Network is unreachable', code)),
            CauseIndisponibilite.reseau);
        expect(sondes, 0);
      });
    }
  });

  group('cas ambigus : la sonde tranche', () {
    test('délai dépassé, internet joignable : le serveur ne répond pas',
        () async {
      final diagnostic = DiagnosticReseau(sonde: () async => true);
      expect(await diagnostic.causeDe(TimeoutException('25 s')),
          CauseIndisponibilite.serveur);
    });

    test('délai dépassé, internet injoignable : pas d\'internet', () async {
      final diagnostic = DiagnosticReseau(sonde: () async => false);
      expect(await diagnostic.causeDe(TimeoutException('25 s')),
          CauseIndisponibilite.reseau);
    });

    test('échec DNS : sondé aussi', () async {
      final diagnostic = DiagnosticReseau(sonde: () async => false);
      expect(
          await diagnostic.causeDe(
              systeme("Failed host lookup: 'api.tmk'", 8)),
          CauseIndisponibilite.reseau);
    });

    test('sonde impossible (web) : cause inconnue', () async {
      final diagnostic = DiagnosticReseau(sonde: () async => null);
      expect(await diagnostic.causeDe(TimeoutException('25 s')),
          CauseIndisponibilite.inconnue);
    });

    test('une sonde en échec ne fait rien planter', () async {
      final diagnostic =
          DiagnosticReseau(sonde: () => Future.error(StateError('x')));
      expect(await diagnostic.causeDe(TimeoutException('25 s')),
          CauseIndisponibilite.inconnue);
    });
  });

  group('une sonde pour plusieurs échecs', () {
    test('les échecs simultanés partagent la même sonde', () async {
      var sondes = 0;
      final reponse = Completer<bool?>();
      final diagnostic = DiagnosticReseau(sonde: () {
        sondes++;
        return reponse.future;
      });

      final causes = [
        for (var i = 0; i < 5; i++) diagnostic.causeDe(TimeoutException('x'))
      ];
      reponse.complete(true);

      expect(await Future.wait(causes),
          everyElement(CauseIndisponibilite.serveur));
      expect(sondes, 1);
    });

    test('le résultat est retenu quelques secondes, puis resondé', () async {
      var sondes = 0;
      var maintenant = DateTime(2026, 10, 26, 14);
      final diagnostic = DiagnosticReseau(
        sonde: () async {
          sondes++;
          return true;
        },
        maintenant: () => maintenant,
      );

      await diagnostic.causeDe(TimeoutException('x'));
      maintenant = maintenant.add(const Duration(seconds: 5));
      await diagnostic.causeDe(TimeoutException('x'));
      expect(sondes, 1);

      maintenant = maintenant.add(const Duration(seconds: 10));
      await diagnostic.causeDe(TimeoutException('x'));
      expect(sondes, 2);
    });
  });

  group('accès actif : activer, ou réparer l\'accès', () {
    late int sondes;

    DiagnosticReseau avec(AccesReseau acces, {bool internet = false}) =>
        DiagnosticReseau(
          acces: () async => acces,
          sonde: () async {
            sondes++;
            return internet;
          },
        );

    setUp(() => sondes = 0);

    test('Wi-Fi et données coupés : à activer, sans attendre de sonde',
        () async {
      expect(await avec(AccesReseau.aucun).causeDe(TimeoutException('x')),
          CauseIndisponibilite.reseauDesactive);
      expect(sondes, 0);
    });

    test('Wi-Fi actif, sonde négative : le Wi-Fi n\'a pas internet', () async {
      expect(await avec(AccesReseau.wifi).causeDe(TimeoutException('x')),
          CauseIndisponibilite.wifiSansInternet);
    });

    test('données actives, réseau injoignable : données sans internet',
        () async {
      expect(
          await avec(AccesReseau.donneesMobiles)
              .causeDe(systeme('Network is unreachable', 101)),
          CauseIndisponibilite.donneesSansInternet);
      expect(sondes, 0);
    });

    test('accès actif et internet joignable : c\'est le serveur', () async {
      expect(
          await avec(AccesReseau.wifi, internet: true)
              .causeDe(TimeoutException('x')),
          CauseIndisponibilite.serveur);
    });

    test('connexion refusée : le serveur, même si l\'accès semble coupé',
        () async {
      expect(
          await avec(AccesReseau.aucun)
              .causeDe(systeme('Connection refused', 111)),
          CauseIndisponibilite.serveur);
    });

    test('accès illisible (plugin absent) : on sonde comme avant', () async {
      final diagnostic = DiagnosticReseau(
        acces: () => throw StateError('plugin'),
        sonde: () async => false,
      );
      expect(await diagnostic.causeDe(TimeoutException('x')),
          CauseIndisponibilite.reseau);
    });

    test('lecture de connectivity_plus', () {
      expect(accesDepuis([ConnectivityResult.none]), AccesReseau.aucun);
      expect(accesDepuis([]), AccesReseau.aucun);
      expect(accesDepuis([ConnectivityResult.wifi]), AccesReseau.wifi);
      expect(accesDepuis([ConnectivityResult.mobile]),
          AccesReseau.donneesMobiles);
      expect(
          accesDepuis([ConnectivityResult.mobile, ConnectivityResult.wifi]),
          AccesReseau.wifi,
          reason: 'le système passe par le Wi-Fi');
      expect(accesDepuis([ConnectivityResult.vpn]), AccesReseau.autre);
    });

    test('côté téléphone ou côté serveur', () {
      expect(CauseIndisponibilite.reseauDesactive.estReseau, isTrue);
      expect(CauseIndisponibilite.wifiSansInternet.estReseau, isTrue);
      expect(CauseIndisponibilite.serveur.estReseau, isFalse);
      expect(CauseIndisponibilite.inconnue.estReseau, isFalse);
    });
  });
}
