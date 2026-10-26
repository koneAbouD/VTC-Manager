import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_cache/tmk_cache.dart';

void main() {
  late StockageMemoire stockage;
  late DateTime maintenant;
  late ReponseCache cache;

  ReponseCache nouveauCache({List<int>? cle, int entreesMax = 500}) =>
      ReponseCache(
        stockage: stockage,
        chiffreur: ChiffreurCache.avecCle(cle ?? List.filled(32, 7)),
        maintenant: () => maintenant,
        entreesMax: entreesMax,
      );

  setUp(() {
    stockage = StockageMemoire();
    maintenant = DateTime(2026, 10, 26, 14, 32);
    cache = nouveauCache();
  });

  test('rejoue le dernier corps enregistré, avec son heure', () async {
    await cache.ecrire('/vehicules', utf8.encode('[1]'), proprietaire: 'a');
    maintenant = maintenant.add(const Duration(minutes: 5));
    await cache.ecrire('/vehicules', utf8.encode('[1,2]'), proprietaire: 'a');

    maintenant = maintenant.add(const Duration(hours: 1));
    final lu = await cache.lire('/vehicules', proprietaire: 'a');

    expect(utf8.decode(lu!.corps), '[1,2]');
    expect(lu.enregistreLe, DateTime(2026, 10, 26, 14, 37));
  });

  test('rien pour une URL jamais lue', () async {
    expect(await cache.lire('/chauffeurs'), isNull);
  });

  test("le contenu n'est jamais stocké en clair, ni l'URL", () async {
    await cache.ecrire('/chauffeurs?recherche=Kone',
        utf8.encode('{"telephone":"+2250700000000"}'));

    final ligne = (await stockage.lire(
        await ChiffreurCache.avecCle(List.filled(32, 7))
            .hacher('/chauffeurs?recherche=Kone')))!;
    expect(ligne.cle, isNot(contains('Kone')));
    expect(utf8.decode(ligne.contenu, allowMalformed: true),
        isNot(contains('2250700000000')));
  });

  test("une autre clé de chiffrement ne lit rien (réinstallation)", () async {
    await cache.ecrire('/vehicules', utf8.encode('[1]'));
    final autre = nouveauCache(cle: List.filled(32, 9));

    expect(await autre.lire('/vehicules'), isNull);
  });

  test("un contenu recopié sous une autre URL ne se déchiffre pas", () async {
    final chiffreur = ChiffreurCache.avecCle(List.filled(32, 7));
    await cache.ecrire('/a', utf8.encode('secret'));
    final source = (await stockage.lire(await chiffreur.hacher('/a')))!;
    await stockage.ecrire(LigneStockee(
      cle: await chiffreur.hacher('/b'),
      proprietaire: source.proprietaire,
      contenu: source.contenu,
      enregistreLe: source.enregistreLe,
    ));

    expect(await cache.lire('/b'), isNull);
  });

  test('au-delà de 30 jours, la réponse n\'est plus servie', () async {
    await cache.ecrire('/soldes', utf8.encode('{}'));
    maintenant = maintenant.add(const Duration(days: 31));

    expect(await cache.lire('/soldes'), isNull);
  });

  group('changement de compte', () {
    test("les réponses d'un autre compte ne sont pas servies", () async {
      await cache.ecrire('/me/compte', utf8.encode('{"solde":1}'),
          proprietaire: 'chauffeur-a');

      expect(await cache.lire('/me/compte', proprietaire: 'chauffeur-b'),
          isNull);
    });

    test('le premier enregistrement du nouveau compte efface l\'ancien',
        () async {
      await cache.ecrire('/a', utf8.encode('1'), proprietaire: 'a');
      await cache.ecrire('/b', utf8.encode('2'), proprietaire: 'b');

      expect(stockage.taille, 1);
      expect(await cache.lire('/a'), isNull);
    });
  });

  group('revalidation', () {
    test("l'ETag de la réponse est retrouvé sans la déchiffrer", () async {
      await cache.ecrire('/vehicules', utf8.encode('[1]'),
          proprietaire: 'a', etag: 'W/"0abc"');

      expect(await cache.etag('/vehicules', proprietaire: 'a'), 'W/"0abc"');
      expect(await cache.etag('/vehicules', proprietaire: 'b'), isNull,
          reason: "pas de revalidation d'une réponse d'un autre compte");
    });

    test('une confirmation (304) rajeunit la réponse', () async {
      await cache.ecrire('/vehicules', utf8.encode('[1]'), etag: 'W/"1"');
      maintenant = maintenant.add(const Duration(days: 29));
      await cache.confirmer('/vehicules');
      maintenant = maintenant.add(const Duration(days: 5));

      final lu = await cache.lire('/vehicules');
      expect(lu, isNotNull, reason: 'confirmée il y a 5 jours, pas 34');
      expect(lu!.enregistreLe, DateTime(2026, 11, 24, 14, 32));
      expect(await cache.etag('/vehicules'), 'W/"1"');
    });

    test('au-delà de 30 jours, plus de revalidation non plus', () async {
      await cache.ecrire('/vehicules', utf8.encode('[1]'), etag: 'W/"1"');
      maintenant = maintenant.add(const Duration(days: 31));

      expect(await cache.etag('/vehicules'), isNull);
    });
  });

  test('vider efface tout', () async {
    await cache.ecrire('/a', utf8.encode('1'), proprietaire: 'a');
    await cache.vider();

    expect(stockage.taille, 0);
  });

  test("l'élagage garde les plus récentes", () async {
    cache = nouveauCache(entreesMax: 10);
    for (var i = 0; i < 25; i++) {
      maintenant = maintenant.add(const Duration(minutes: 1));
      await cache.ecrire('/page/$i', utf8.encode('$i'));
    }

    expect(stockage.taille, 10);
    expect(await cache.lire('/page/24'), isNotNull);
    expect(await cache.lire('/page/14'), isNull);
  });

  test("une panne du stockage n'est jamais remontée", () async {
    final enPanne = ReponseCache(
      stockage: _StockageEnPanne(),
      chiffreur: ChiffreurCache.avecCle(List.filled(32, 7)),
    );

    await enPanne.ecrire('/a', utf8.encode('1'));
    expect(await enPanne.lire('/a'), isNull);
    await enPanne.vider();
  });
}

class _StockageEnPanne extends StockageMemoire {
  @override
  Future<LigneStockee?> lire(String cle) => throw StateError('disque plein');

  @override
  Future<void> ecrire(LigneStockee ligne) => throw StateError('disque plein');

  @override
  Future<void> vider() => throw StateError('disque plein');
}
