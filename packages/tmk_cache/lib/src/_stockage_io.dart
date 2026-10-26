import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'stockage_reponses.dart';

StockageReponses ouvrirStockage() => _StockageSqlite(_BaseCache());

/// Base `tmk_cache`, ouverte dans un isolate dédié : ni l'écriture ni la
/// lecture ne bloquent l'interface.
///
/// L'ouverture n'a lieu qu'à la première requête, et son échec remonte à
/// cette requête — que [ReponseCache] avale. (`driftDatabase` de drift_flutter
/// ouvre dès la construction et laisse alors échapper l'erreur.)
///
/// Une seule table, manipulée en SQL : la génération de code drift arrivera
/// avec les tables typées de la consultation hors ligne.
class _BaseCache extends GeneratedDatabase {
  _BaseCache()
      : super(LazyDatabase(() async {
          final dossier = await getApplicationSupportDirectory();
          return NativeDatabase.createInBackground(
              File(p.join(dossier.path, 'tmk_cache.sqlite')));
        }));

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await customStatement('''
            CREATE TABLE reponses (
              cle TEXT NOT NULL PRIMARY KEY,
              proprietaire TEXT,
              contenu BLOB NOT NULL,
              enregistre_le INTEGER NOT NULL
            )''');
          await customStatement(
              'CREATE INDEX reponses_enregistre_le ON reponses (enregistre_le)');
        },
      );
}

class _StockageSqlite implements StockageReponses {
  final _BaseCache _db;

  _StockageSqlite(this._db);

  @override
  Future<LigneStockee?> lire(String cle) async {
    final ligne = await _db.customSelect(
      'SELECT proprietaire, contenu, enregistre_le FROM reponses WHERE cle = ?',
      variables: [Variable.withString(cle)],
    ).getSingleOrNull();
    if (ligne == null) return null;
    return LigneStockee(
      cle: cle,
      proprietaire: ligne.readNullable<String>('proprietaire'),
      contenu: ligne.read<Uint8List>('contenu'),
      enregistreLe: DateTime.fromMillisecondsSinceEpoch(
          ligne.read<int>('enregistre_le')),
    );
  }

  @override
  Future<void> ecrire(LigneStockee ligne) => _db.customInsert(
        'INSERT OR REPLACE INTO reponses '
        '(cle, proprietaire, contenu, enregistre_le) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(ligne.cle),
          Variable<String>(ligne.proprietaire),
          Variable.withBlob(ligne.contenu),
          Variable.withInt(ligne.enregistreLe.millisecondsSinceEpoch),
        ],
      );

  @override
  Future<void> supprimerAutresProprietaires(String proprietaire) =>
      _db.customStatement(
        'DELETE FROM reponses '
        'WHERE proprietaire IS NULL OR proprietaire <> ?',
        [proprietaire],
      );

  @override
  Future<void> elaguer({
    required DateTime avant,
    required int entreesMax,
  }) async {
    await _db.customStatement(
      'DELETE FROM reponses WHERE enregistre_le < ?',
      [avant.millisecondsSinceEpoch],
    );
    await _db.customStatement(
      'DELETE FROM reponses WHERE cle NOT IN '
      '(SELECT cle FROM reponses ORDER BY enregistre_le DESC LIMIT ?)',
      [entreesMax],
    );
  }

  @override
  Future<void> vider() => _db.customStatement('DELETE FROM reponses');
}
