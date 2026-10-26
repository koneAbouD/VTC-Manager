import 'stockage_reponses.dart';

/// Sur le web, pas de base locale : le cache ne dure que le temps de l'onglet.
StockageReponses ouvrirStockage() => StockageMemoire();
