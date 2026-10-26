import 'dart:async';

import 'package:tmk_cache/tmk_cache.dart';

/// Configuration commune à tous les tests de ce dossier.
///
/// Le cache des réponses passe en mémoire : sa base SQLite ne répond pas dans
/// l'environnement des tests de widgets, et chaque lecture y attendrait le
/// cache jusqu'à expiration de son délai.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ReponseCache.instance = ReponseCache(
    stockage: StockageMemoire(),
    chiffreur: ChiffreurCache.avecCle(List.filled(32, 0)),
  );
  await testMain();
}
