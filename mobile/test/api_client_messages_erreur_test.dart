import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  test('une coupure réseau garde le message « serveur injoignable »', () async {
    final client = ApiClient(
      const _SansJeton(),
      MockClient((_) async => throw http.ClientException('Connection refused')),
    );
    await expectLater(
        client.get('/vehicules'), _reseau(kMsgServeurInjoignable));
  });
}
