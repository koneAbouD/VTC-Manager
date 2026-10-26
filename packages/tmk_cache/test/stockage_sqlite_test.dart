import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_cache/src/_stockage_io.dart';
import 'package:tmk_cache/tmk_cache.dart';

/// La base réelle (SQLite en mémoire, bibliothèque de la machine) : requêtes
/// et migration de schéma.
void main() {
  // Une base par test, chacune sur sa propre mémoire : aucun risque de course.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  LigneStockee ligne(String cle, int minute, {String? proprietaire = 'a'}) =>
      LigneStockee(
        cle: cle,
        proprietaire: proprietaire,
        contenu: Uint8List.fromList([1, 2, 3]),
        enregistreLe: DateTime(2026, 10, 26, 14, minute),
        etag: 'W/"$cle"',
      );

  test('écrit, relit, confirme, élague et purge', () async {
    final stockage = ouvrirStockageSur(NativeDatabase.memory());

    await stockage.ecrire(ligne('x', 1));
    await stockage.ecrire(ligne('y', 2));
    await stockage.ecrire(ligne('z', 3, proprietaire: 'b'));

    final x = (await stockage.lire('x'))!;
    expect(x.contenu, [1, 2, 3]);
    expect(x.etag, 'W/"x"');
    expect(x.enregistreLe, DateTime(2026, 10, 26, 14, 1));

    await stockage.confirmer('x', DateTime(2026, 10, 26, 15));
    expect((await stockage.lire('x'))!.enregistreLe, DateTime(2026, 10, 26, 15));

    await stockage.supprimerAutresProprietaires('a');
    expect(await stockage.lire('z'), isNull);

    await stockage.elaguer(avant: DateTime(2026), entreesMax: 1);
    expect(await stockage.lire('x'), isNotNull, reason: 'la plus récente');
    expect(await stockage.lire('y'), isNull);

    await stockage.vider();
    expect(await stockage.lire('x'), isNull);
  });

  test('une base de la phase 1 (schéma 1) gagne la colonne etag', () async {
    final stockage = ouvrirStockageSur(NativeDatabase.memory(setup: (db) {
      db.execute('''
        CREATE TABLE reponses (
          cle TEXT NOT NULL PRIMARY KEY,
          proprietaire TEXT,
          contenu BLOB NOT NULL,
          enregistre_le INTEGER NOT NULL
        )''');
      db.execute(
          "INSERT INTO reponses VALUES ('ancienne', 'a', x'01', 1761487920000)");
      db.userVersion = 1;
    }));

    final ancienne = (await stockage.lire('ancienne'))!;
    expect(ancienne.etag, isNull);
    expect(ancienne.contenu, [1]);

    await stockage.ecrire(ligne('neuve', 4));
    expect((await stockage.lire('neuve'))!.etag, 'W/"neuve"');
  });
}
