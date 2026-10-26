import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tmk_cache/tmk_cache.dart';

import 'package:vtc_chauffeur/core/error/exception.dart';
import 'package:vtc_chauffeur/core/network/api_client.dart';
import 'package:vtc_chauffeur/core/storage/secure_storage.dart';

/// Messages d'erreur montrés au chauffeur quand le serveur est hors d'atteinte
/// ou répond mal : jamais de code HTTP brut, de page HTML ni de détail
/// technique, toujours une phrase qui dit quoi faire.
class _SansJeton extends SecureStorage {
  const _SansJeton();

  @override
  Future<String?> getAccessToken() async => null;
}

/// Le backend répond en UTF-8 ; un [charset] différent simule un proxy.
ApiClient _client(int status, {String corps = '', String charset = 'utf-8'}) =>
    ApiClient(
      const _SansJeton(),
      MockClient(
        (_) async => http.Response(
          corps,
          status,
          headers: {'content-type': 'text/plain; charset=$charset'},
        ),
      ),
    );

Matcher _reseau(String message) => throwsA(
  isA<NetworkException>().having((e) => e.message, 'message', message),
);

Matcher _api(int status, String message) => throwsA(
  isA<ApiException>()
      .having((e) => e.statusCode, 'statusCode', status)
      .having((e) => e.message, 'message', message),
);

void main() {
  const portail = '<html><body>Connectez-vous au Wi-Fi</body></html>';

  group('redirection (portail Wi-Fi, forfait épuisé, proxy)', () {
    test('un 302 sur une lecture est une erreur réseau', () async {
      await expectLater(
        _client(302, corps: portail).get('/me/recettes'),
        _reseau(kMsgAccesDetourne),
      );
    });

    test('un 302 sur un envoi aussi', () async {
      await expectLater(
        _client(302, corps: portail).post('/auth/otp', {'telephone': 'x'}),
        _reseau(kMsgAccesDetourne),
      );
    });

    test('un 307 sur un téléchargement aussi', () async {
      await expectLater(
        _client(307, corps: portail).getBytes('/me/arretes/1/pdf'),
        _reseau(kMsgAccesDetourne),
      );
    });
  });

  group('serveur indisponible ou en erreur', () {
    test('une page HTML de proxy n\'est jamais affichée', () async {
      await expectLater(
        _client(502, corps: portail).get('/me/recettes'),
        _api(502, kMsgServeurIndisponible),
      );
    });

    test(
      'une page de proxy en Latin-1 ne fait pas planter le décodage',
      () async {
        await expectLater(
          _client(
            502,
            corps: '<html><body>Accès refusé</body></html>',
            charset: 'iso-8859-1',
          ).get('/me/recettes'),
          _api(502, kMsgServeurIndisponible),
        );
      },
    );

    test('502 / 503 / 504 sans message : momentanément indisponible', () async {
      for (final status in [502, 503, 504]) {
        await expectLater(
          _client(status).get('/me/recettes'),
          _api(status, kMsgServeurIndisponible),
          reason: 'statut $status',
        );
      }
    });

    test('un 500 sans message : erreur côté serveur, sans code', () async {
      await expectLater(
        _client(500).get('/me/recettes'),
        _api(500, kMsgErreurServeur),
      );
    });

    test('un message du backend reste prioritaire', () async {
      const motif = 'Code expiré, demandez-en un nouveau.';
      await expectLater(
        _client(400, corps: '{"message":"$motif"}').post('/auth/otp/verifier'),
        _api(400, motif),
      );
    });

    test('un refus de téléchargement rend le message, pas le JSON', () async {
      const motif = "Le décompte de cet arrêté n'est pas encore disponible.";
      await expectLater(
        _client(
          409,
          corps: '{"status":409,"message":"$motif"}',
        ).getBytes('/me/arretes/1/pdf'),
        _api(409, motif),
      );
    });
  });

  group('coupure réseau', () {
    test('sans détail technique', () async {
      final client = ApiClient(
        const _SansJeton(),
        MockClient(
          (_) async => throw http.ClientException('coupure'),
        ),
      );
      await expectLater(
        client.get('/me/recettes'),
        _reseau(kMsgPasInternet),
      );
      await expectLater(
        client.getBytes('/me/arretes/1/pdf'),
        _reseau(kMsgPasInternet),
      );
    });
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
        client(_ErreurSocket('Connection refused', 61)).get('/me/recettes'),
        cause(CauseIndisponibilite.serveur, kMsgServeurInjoignable),
      );
      expect(sondes, 0);
    });

    test('réseau injoignable : pas d\'internet, pas besoin de sonder',
        () async {
      await expectLater(
        client(_ErreurSocket('Network is unreachable', 101)).get('/me/recettes'),
        cause(CauseIndisponibilite.reseau, kMsgPasInternet),
      );
      expect(sondes, 0);
    });

    test('délai dépassé, internet joignable : le serveur ne répond pas',
        () async {
      await expectLater(
        client(TimeoutException('25 s'), internet: true).get('/me/recettes'),
        cause(CauseIndisponibilite.serveur, kMsgServeurInjoignable),
      );
      expect(sondes, 1);
    });

    test('délai dépassé, internet injoignable : pas d\'internet', () async {
      await expectLater(
        client(TimeoutException('25 s'), internet: false).post('/me/paiements', {}),
        cause(CauseIndisponibilite.reseau, kMsgPasInternet),
      );
    });

    test('Wi-Fi et données coupés : il faut en activer un', () async {
      await expectLater(
        client(TimeoutException('25 s'), acces: AccesReseau.aucun)
            .get('/me/recettes'),
        cause(CauseIndisponibilite.reseauDesactive, kMsgReseauDesactive),
      );
      expect(sondes, 0, reason: 'rien à sonder, tout est coupé');
    });

    test('Wi-Fi connecté sans internet', () async {
      await expectLater(
        client(TimeoutException('25 s'),
                internet: false, acces: AccesReseau.wifi)
            .get('/me/recettes'),
        cause(CauseIndisponibilite.wifiSansInternet, kMsgWifiSansInternet),
      );
    });

    test('données mobiles actives sans internet', () async {
      await expectLater(
        client(_ErreurSocket('Network is unreachable', 101),
                acces: AccesReseau.donneesMobiles)
            .get('/me/recettes'),
        cause(CauseIndisponibilite.donneesSansInternet,
            kMsgDonneesSansInternet),
      );
    });

    test('cause impossible à établir : message qui n\'accuse personne',
        () async {
      await expectLater(
        client(http.ClientException('coupure'), internet: null).get('/me/recettes'),
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

