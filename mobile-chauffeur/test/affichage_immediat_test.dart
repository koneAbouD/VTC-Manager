import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tmk_cache/tmk_cache.dart';
import 'package:vtc_chauffeur/core/network/api_client.dart';
import 'package:vtc_chauffeur/core/providers/core_providers.dart';
import 'package:vtc_chauffeur/core/storage/secure_storage.dart';
import 'package:vtc_chauffeur/features/recette/domain/entities/ligne_recette.dart';
import 'package:vtc_chauffeur/features/recette/presentation/providers/recette_providers.dart';

/// Les pages du chauffeur (ici ses recettes) : à l'ouverture, la dernière
/// liste connue s'affiche le temps que le serveur réponde, au lieu d'un
/// indicateur de chargement.
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

  setUp(() {
    cache = ReponseCache(
      stockage: StockageMemoire(),
      chiffreur: ChiffreurCache.avecCle(List.filled(32, 8)),
    );
    serveur = Completer();
  });

  /// Une ouverture de la page : un conteneur neuf, comme au démarrage.
  ProviderContainer ouverture() => ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(ApiClient(
          const _SansJeton(),
          MockClient((_) => serveur.future),
          cache,
          EtatHorsLigne(),
        )),
      ]);

  http.Response recettes(List<int> ids) => http.Response(
      jsonEncode([
        for (final id in ids)
          {'id': id, 'dateRecette': '2026-10-26', 'montantAttendu': 15000}
      ]),
      200);

  List<int>? affichees(ProviderContainer c) =>
      c.read(recettesProvider).valueOrNull?.map((r) => r.id).toList();

  test("à l'ouverture suivante, la dernière liste s'affiche aussitôt", () async {
    final premiere = ouverture();
    final sub1 = premiere.listen(recettesProvider, (_, _) {});
    serveur.complete(recettes([1, 2]));
    await premiere.read(recettesProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    sub1.close();
    premiere.dispose();

    serveur = Completer();
    final page = ouverture();
    final sub = page.listen<AsyncValue<List<LigneRecette>>>(
        recettesProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(affichees(page), [1, 2],
        reason: "pas d'indicateur de chargement : la liste connue est là");

    serveur.complete(recettes([3, 1, 2]));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(affichees(page), [3, 1, 2]);
    sub.close();
    page.dispose();
  });

  test('toute première ouverture : chargement, comme avant', () async {
    final page = ouverture();
    final sub = page.listen(recettesProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(page.read(recettesProvider).isLoading, isTrue);
    expect(affichees(page), isNull);

    serveur.complete(recettes([1]));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(affichees(page), [1]);
    sub.close();
    page.dispose();
  });

  test('un échec du serveur remonte comme avant', () async {
    final page = ouverture();
    final sub = page.listen(recettesProvider, (_, _) {});
    serveur.complete(http.Response.bytes(
        utf8.encode(jsonEncode({'message': 'Refusé.'})), 403));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(page.read(recettesProvider).error, 'Refusé.');
    sub.close();
    page.dispose();
  });
}
