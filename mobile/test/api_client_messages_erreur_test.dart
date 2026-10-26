import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tmk_cache/tmk_cache.dart';

import 'package:vtc_manager/core/error/exception.dart';
import 'package:vtc_manager/core/network/api_client.dart';
import 'package:vtc_manager/core/storage/secure_storage.dart';

/// Messages d'erreur montrés à l'utilisateur quand le serveur est hors
/// d'atteinte ou répond mal : jamais de code HTTP brut (« Erreur serveur
/// (302) »), toujours une phrase qui dit quoi faire.
class _SansJeton extends SecureStorage {
  const _SansJeton();

  @override
  Future<String?> getAccessToken() async => null;
}

ApiClient _client(int status,
        {String corps = '', Map<String, String>? entetes}) =>
    ApiClient(
      const _SansJeton(),
      MockClient((_) async =>
          http.Response(corps, status, headers: entetes ?? const {})),
    );

Matcher _reseau(String message) => throwsA(
    isA<NetworkException>().having((e) => e.message, 'message', message));

Matcher _api(int status, String message) => throwsA(isA<ApiException>()
    .having((e) => e.statusCode, 'statusCode', status)
    .having((e) => e.message, 'message', message));

void main() {
  group('redirection (portail Wi-Fi, forfait épuisé, proxy)', () {
    // Le portail répond par une page HTML de connexion : c'est elle qui
    // produisait « Erreur serveur (302) ».
    const portail = '<html><body>Connectez-vous au Wi-Fi</body></html>';

    test('un 302 sur une lecture est une erreur réseau, pas serveur', () async {
      await expectLater(
        _client(302,
            corps: portail,
            entetes: {'location': 'http://portail.local'}).get('/vehicules'),
        _reseau(kMsgAccesDetourne),
      );
    });

    test('un 302 sur un envoi aussi', () async {
      await expectLater(
        _client(302, corps: portail).post('/recettes', {'montant': 1000}),
        _reseau(kMsgAccesDetourne),
      );
    });

    test('un 307 sur un téléchargement aussi', () async {
      await expectLater(
        _client(307, corps: portail).getBytes('/recus/1/pdf'),
        _reseau(kMsgAccesDetourne),
      );
    });

    test('le message ne montre aucun code HTTP', () {
      expect(kMsgAccesDetourne, isNot(contains('302')));
      expect(kMsgAccesDetourne, contains('réseau'));
    });
  });

  group('serveur indisponible ou en erreur', () {
    test('502 / 503 / 504 sans message : serveur momentanément indisponible',
        () async {
      for (final status in [502, 503, 504]) {
        await expectLater(
          _client(status, corps: '<html>Bad gateway</html>').get('/vehicules'),
          _api(status, kMsgServeurIndisponible),
          reason: 'statut $status',
        );
      }
    });

    test('une page de proxy en Latin-1 ne fait pas planter le décodage',
        () async {
      // Sans charset UTF-8, les accents partent en Latin-1 : illisibles en
      // UTF-8, ils ne doivent plus lever de FormatException.
      await expectLater(
        _client(502,
                corps: '<html><body>Accès refusé</body></html>',
                entetes: {'content-type': 'text/html; charset=iso-8859-1'})
            .get('/vehicules'),
        _api(502, kMsgServeurIndisponible),
      );
    });

    test('un 503 du backend garde son propre message', () async {
      const motif = "Service d'authentification indisponible.";
      await expectLater(
        _client(503, corps: '{"message":"$motif"}').get('/vehicules'),
        _api(503, motif),
      );
    });

    test('un 500 sans message : erreur côté serveur, sans code', () async {
      await expectLater(
        _client(500).get('/vehicules'),
        _api(500, kMsgErreurServeur),
      );
    });

    test('un code inattendu sans message : réponse inattendue', () async {
      await expectLater(
        _client(418).get('/vehicules'),
        _api(418, kMsgReponseInattendue),
      );
    });
  });

  test('une coupure sans cause lisible, sonde négative : pas d\'internet',
      () async {
    final client = ApiClient(
      const _SansJeton(),
      MockClient((_) async => throw http.ClientException('coupure')),
    );
    await expectLater(client.get('/vehicules'), _reseau(kMsgPasInternet));
  });

  group('pas d\'internet ou serveur indisponible', () {
    late int sondes;

    ApiClient client(
      Object erreur, {
      bool? internet,
      AccesReseau acces = AccesReseau.inconnu,
    }) =>
        ApiClient(
          const _SansJeton(),
          MockClient((_) async => throw erreur),
          null,
          null,
          DiagnosticReseau(
            acces: () async => acces,
            sonde: () async {
              sondes++;
              return internet;
            },
          ),
        );

    Matcher cause(CauseIndisponibilite c, String message) => throwsA(
        isA<NetworkException>()
            .having((e) => e.cause, 'cause', c)
            .having((e) => e.message, 'message', message));

    setUp(() => sondes = 0);

    test('connexion refusée : le serveur est arrêté, pas besoin de sonder',
        () async {
      await expectLater(
        client(_ErreurSocket('Connection refused', 61)).get('/vehicules'),
        cause(CauseIndisponibilite.serveur, kMsgServeurInjoignable),
      );
      expect(sondes, 0);
    });

    test('réseau injoignable : pas d\'internet, pas besoin de sonder',
        () async {
      await expectLater(
        client(_ErreurSocket('Network is unreachable', 101)).get('/vehicules'),
        cause(CauseIndisponibilite.reseau, kMsgPasInternet),
      );
      expect(sondes, 0);
    });

    test('délai dépassé, internet joignable : le serveur ne répond pas',
        () async {
      await expectLater(
        client(TimeoutException('25 s'), internet: true).get('/vehicules'),
        cause(CauseIndisponibilite.serveur, kMsgServeurInjoignable),
      );
      expect(sondes, 1);
    });

    test('délai dépassé, internet injoignable : pas d\'internet', () async {
      await expectLater(
        client(TimeoutException('25 s'), internet: false).post('/recettes', {}),
        cause(CauseIndisponibilite.reseau, kMsgPasInternet),
      );
    });

    test('Wi-Fi et données coupés : il faut en activer un', () async {
      await expectLater(
        client(TimeoutException('25 s'), acces: AccesReseau.aucun)
            .get('/vehicules'),
        cause(CauseIndisponibilite.reseauDesactive, kMsgReseauDesactive),
      );
      expect(sondes, 0, reason: 'rien à sonder, tout est coupé');
    });

    test('Wi-Fi connecté sans internet', () async {
      await expectLater(
        client(TimeoutException('25 s'),
                internet: false, acces: AccesReseau.wifi)
            .get('/vehicules'),
        cause(CauseIndisponibilite.wifiSansInternet, kMsgWifiSansInternet),
      );
    });

    test('données mobiles actives sans internet', () async {
      await expectLater(
        client(_ErreurSocket('Network is unreachable', 101),
                acces: AccesReseau.donneesMobiles)
            .get('/vehicules'),
        cause(CauseIndisponibilite.donneesSansInternet,
            kMsgDonneesSansInternet),
      );
    });

    test('cause impossible à établir : message qui n\'accuse personne',
        () async {
      await expectLater(
        client(http.ClientException('coupure'), internet: null).get('/vehicules'),
        cause(CauseIndisponibilite.inconnue, kMsgConnexionImpossible),
      );
    });
  });
}

/// Ce que lève le client HTTP sur une erreur système : une ClientException
/// qui est aussi une SocketException (avec son code d'erreur).
class _ErreurSocket extends http.ClientException implements SocketException {
  @override
  final OSError osError;

  _ErreurSocket(super.message, int code) : osError = OSError(message, code);

  @override
  InternetAddress? get address => null;

  @override
  int? get port => null;
}

