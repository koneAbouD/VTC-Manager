import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tmk_cache/tmk_cache.dart';

import 'package:vtc_manager/core/error/exception.dart';
import 'package:vtc_manager/core/error/failure.dart';
import 'package:vtc_manager/core/network/api_client.dart';
import 'package:vtc_manager/core/network/page_result.dart';
import 'package:vtc_manager/core/pagination/paged_list_notifier.dart';
import 'package:vtc_manager/core/storage/secure_storage.dart';

/// Les listes paginées (recettes, cotisations, pénalités…) affichent leur
/// dernière première page connue le temps que le serveur réponde — avec le
/// code qui les charge d'ordinaire, lu sur le cache seul.
class _SansJeton extends SecureStorage {
  const _SansJeton();

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;
}

void main() {
  late ReponseCache cache;
  late Completer<http.Response> serveur;
  late ApiClient client;
  var appels = 0;

  setUp(() {
    cache = ReponseCache(
      stockage: StockageMemoire(),
      chiffreur: ChiffreurCache.avecCle(List.filled(32, 3)),
    );
    appels = 0;
    serveur = Completer();
    client = ApiClient(
      const _SansJeton(),
      MockClient((_) {
        appels++;
        return serveur.future;
      }),
      cache,
      EtatHorsLigne(),
    );
  });

  http.Response page(List<int> ids, {bool last = false}) => http.Response(
      jsonEncode({
        'content': [for (final id in ids) {'id': id}],
        'page': 0,
        'size': 20,
        'last': last,
      }),
      200);

  /// Le fetcher d'un écran : repository qui traduit les exceptions en échec.
  Future<Either<Failure, PageResult<int>>> lignes(int page, int size) async {
    try {
      final data = await client.get('/recettes/lignes/page',
          query: {'page': '$page', 'size': '$size'});
      return Right(PageResult.fromJson(
          data as Map<String, dynamic>, (e) => e['id'] as int));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  Future<void> premiereVisite() async {
    serveur.complete(page([1, 2]));
    await PagedListNotifier<int>().load(lignes);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    serveur = Completer();
  }

  test('la première page connue s\'affiche en attendant le serveur', () async {
    await premiereVisite();
    final notifier = PagedListNotifier<int>();

    final chargement = notifier.load(lignes);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(notifier.state.items, [1, 2]);
    expect(notifier.state.initialLoading, isTrue,
        reason: 'pas de page suivante tant que la vraie n\'est pas là');

    serveur.complete(page([1, 2, 3], last: true));
    await chargement;
    expect(notifier.state.items, [1, 2, 3]);
    expect(notifier.state.initialLoading, isFalse);
  });

  test('la lecture du cache n\'appelle pas le serveur', () async {
    await premiereVisite();
    final avant = appels;

    final enCache = await ApiClient.depuisLeCacheSeul(() => lignes(0, 20));

    expect(enCache.toNullable()?.content, [1, 2]);
    expect(appels, avant);
  });

  test('rien en cache : indicateur de chargement, comme avant', () async {
    final notifier = PagedListNotifier<int>();

    final chargement = notifier.load(lignes);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(notifier.state.items, isEmpty);
    expect(notifier.state.initialLoading, isTrue);

    serveur.complete(page([5], last: true));
    await chargement;
    expect(notifier.state.items, [5]);
  });

  test('un rafraîchissement garde la liste affichée', () async {
    await premiereVisite();
    final notifier = PagedListNotifier<int>();
    serveur.complete(page([1, 2, 3]));
    await notifier.load(lignes);
    serveur = Completer();

    final vus = <List<int>>[];
    notifier.addListener((s) => vus.add(s.items), fireImmediately: false);
    final rafraichi = notifier.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    serveur.complete(page([1, 2, 3, 4], last: true));
    await rafraichi;

    expect(vus.first, [1, 2, 3], reason: 'pas de retour à la page en cache');
    expect(vus.last, [1, 2, 3, 4]);
  });
}
