import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tmk_cache/tmk_cache.dart';

import 'package:vtc_manager/core/error/exception.dart';
import 'package:vtc_manager/core/network/api_client.dart';
import 'package:vtc_manager/core/storage/secure_storage.dart';

/// Sans réseau, une lecture déjà faite rejoue sa dernière réponse au lieu
/// d'afficher un écran vide ; le bandeau dit de quand elle date.
class _Jeton extends SecureStorage {
  final String? sub;

  /// Compte du seul refresh token : application ouverte hors connexion, sans
  /// jeton d'accès.
  final String? subRefresh;
  const _Jeton(this.sub, {this.subRefresh});

  static String _jwt(String sub) =>
      'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': sub})))}.sig';

  @override
  Future<String?> getAccessToken() async => sub == null ? null : _jwt(sub!);

  @override
  Future<String?> getRefreshToken() async =>
      subRefresh == null ? null : _jwt(subRefresh!);
}

void main() {
  late ReponseCache cache;
  late EtatHorsLigne horsLigne;
  late http.Response? Function(http.Request) serveur;

  ApiClient client({String? sub = 'gestionnaire-1', String? subRefresh}) =>
      ApiClient(
        _Jeton(sub, subRefresh: subRefresh),
        MockClient((req) async {
          final reponse = serveur(req);
          if (reponse == null) throw http.ClientException('hors ligne');
          return reponse;
        }),
        cache,
        horsLigne,
      );

  http.Response json(Object corps, [int status = 200]) =>
      http.Response(jsonEncode(corps), status,
          headers: {'content-type': 'application/json'});

  /// Laisse l'écriture du cache, lancée sans être attendue, se terminer.
  Future<void> ecrituresTerminees() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  setUp(() {
    cache = ReponseCache(
      stockage: StockageMemoire(),
      chiffreur: ChiffreurCache.avecCle(List.filled(32, 1)),
    );
    horsLigne = EtatHorsLigne();
  });

  test('sans réseau, rejoue la dernière réponse et lève le bandeau', () async {
    serveur = (_) => json([
          {'id': 1, 'immatriculation': 'AB-123'}
        ]);
    await client().get('/vehicules', query: {'statut': 'ACTIF'});
    await ecrituresTerminees();
    expect(horsLigne.value, isNull);

    serveur = (_) => null;
    final hors = await client().get('/vehicules', query: {'statut': 'ACTIF'});

    expect(hors, [
      {'id': 1, 'immatriculation': 'AB-123'}
    ]);
    expect(horsLigne.value, isNotNull);
  });

  test('le retour du serveur fait tomber le bandeau', () async {
    serveur = (_) => json({'ok': true});
    await client().get('/tableau-bord');
    await ecrituresTerminees();
    serveur = (_) => null;
    await client().get('/tableau-bord');
    expect(horsLigne.value, isNotNull);

    serveur = (_) => json({'ok': true});
    await client().get('/autre');
    expect(horsLigne.value, isNull);
  });

  test('un serveur en maintenance (503) se traite comme une coupure', () async {
    serveur = (_) => json({'solde': 1000});
    await client().get('/tresorerie');
    await ecrituresTerminees();

    serveur = (_) => http.Response('<html>503</html>', 503);
    expect(await client().get('/tresorerie'), {'solde': 1000});
  });

  test("une erreur du serveur n'est jamais masquée par le cache", () async {
    serveur = (_) => json({'id': 4});
    await client().get('/vehicules/4');
    await ecrituresTerminees();

    serveur = (_) => json({'message': 'Véhicule introuvable.'}, 404);
    await expectLater(
      client().get('/vehicules/4'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test("sans réponse en cache, l'erreur réseau remonte telle quelle", () async {
    serveur = (_) => null;
    await expectLater(
      client().get('/jamais-lu'),
      throwsA(isA<NetworkException>()
          .having((e) => e.message, 'message', kMsgServeurInjoignable)),
    );
    expect(horsLigne.value, isNull);
  });

  test('une autre URL (autres filtres) ne reçoit pas la réponse', () async {
    serveur = (_) => json([1]);
    await client().get('/recettes', query: {'mois': '2026-10'});
    await ecrituresTerminees();

    serveur = (_) => null;
    await expectLater(client().get('/recettes', query: {'mois': '2026-09'}),
        throwsA(isA<NetworkException>()));
  });

  test("les écritures ne sont jamais rejouées", () async {
    serveur = (_) => json({'id': 9});
    await client().post('/encaissements', {'montant': 5000});
    await ecrituresTerminees();

    serveur = (_) => null;
    await expectLater(client().post('/encaissements', {'montant': 5000}),
        throwsA(isA<NetworkException>()));
  });

  test("un autre compte ne voit pas les réponses du précédent", () async {
    serveur = (_) => json({'solde': 1});
    await client(sub: 'gestionnaire-1').get('/tresorerie');
    await ecrituresTerminees();

    serveur = (_) => null;
    await expectLater(client(sub: 'gestionnaire-2').get('/tresorerie'),
        throwsA(isA<NetworkException>()));
  });

  group('ouverte hors connexion (pas encore de jeton d\'accès)', () {
    setUp(() async {
      serveur = (_) => json({'solde': 1});
      await client(sub: 'gestionnaire-1').get('/tresorerie');
      await ecrituresTerminees();
      serveur = (_) => null;
    });

    test('le refresh token du coffre désigne le compte', () async {
      expect(
        await client(sub: null, subRefresh: 'gestionnaire-1')
            .get('/tresorerie'),
        {'solde': 1},
      );
    });

    test("un refresh token d'un autre compte ne lit rien", () async {
      await expectLater(
        client(sub: null, subRefresh: 'gestionnaire-2').get('/tresorerie'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
