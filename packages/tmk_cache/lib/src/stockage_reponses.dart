import 'dart:typed_data';

/// Une réponse telle qu'elle est rangée sur l'appareil : déjà chiffrée, sous
/// une clé déjà hachée. Le stockage ne voit jamais ni l'URL ni le contenu.
class LigneStockee {
  final String cle;
  final String? proprietaire;
  final Uint8List contenu;
  final DateTime enregistreLe;

  /// ETag de la réponse : le serveur répond 304 quand il n'a pas changé.
  final String? etag;

  const LigneStockee({
    required this.cle,
    required this.proprietaire,
    required this.contenu,
    required this.enregistreLe,
    this.etag,
  });

  LigneStockee confirmee(DateTime le) => LigneStockee(
        cle: cle,
        proprietaire: proprietaire,
        contenu: contenu,
        enregistreLe: le,
        etag: etag,
      );
}

/// Persistance des réponses : SQLite sur mobile, mémoire sur le web.
abstract class StockageReponses {
  Future<LigneStockee?> lire(String cle);

  /// Remplace la ligne de même clé.
  Future<void> ecrire(LigneStockee ligne);

  /// Le serveur a confirmé la ligne (304) : elle date désormais de [le].
  Future<void> confirmer(String cle, DateTime le);

  /// Efface ce qui a été enregistré pour un autre compte que [proprietaire].
  Future<void> supprimerAutresProprietaires(String proprietaire);

  /// Efface les lignes enregistrées avant [avant], puis les plus anciennes
  /// au-delà de [entreesMax].
  Future<void> elaguer({required DateTime avant, required int entreesMax});

  Future<void> vider();
}

/// Stockage le temps de la session : web, et tests.
class StockageMemoire implements StockageReponses {
  final Map<String, LigneStockee> _lignes = {};

  int get taille => _lignes.length;

  @override
  Future<LigneStockee?> lire(String cle) async => _lignes[cle];

  @override
  Future<void> ecrire(LigneStockee ligne) async => _lignes[ligne.cle] = ligne;

  @override
  Future<void> confirmer(String cle, DateTime le) async {
    final ligne = _lignes[cle];
    if (ligne != null) _lignes[cle] = ligne.confirmee(le);
  }

  @override
  Future<void> supprimerAutresProprietaires(String proprietaire) async =>
      _lignes.removeWhere((_, l) => l.proprietaire != proprietaire);

  @override
  Future<void> elaguer({
    required DateTime avant,
    required int entreesMax,
  }) async {
    _lignes.removeWhere((_, l) => l.enregistreLe.isBefore(avant));
    if (_lignes.length <= entreesMax) return;
    final parAge = _lignes.values.toList()
      ..sort((a, b) => b.enregistreLe.compareTo(a.enregistreLe));
    for (final l in parAge.skip(entreesMax)) {
      _lignes.remove(l.cle);
    }
  }

  @override
  Future<void> vider() async => _lignes.clear();
}
