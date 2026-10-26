import 'package:flutter/foundation.dart';

import '_stockage_io.dart' if (dart.library.js_interop) '_stockage_web.dart';
import 'chiffreur_cache.dart';
import 'stockage_reponses.dart';

/// Une réponse servie depuis le cache, avec l'heure à laquelle le serveur l'a
/// envoyée : l'écran doit pouvoir dire de quand datent les chiffres affichés.
class ReponseEnCache {
  final Uint8List corps;
  final DateTime enregistreLe;

  const ReponseEnCache(this.corps, this.enregistreLe);
}

/// Dernière réponse connue de chaque lecture (GET).
///
/// Une lecture va toujours au serveur ; le cache sert à trois choses :
/// - le secours, pour qu'une coupure n'affiche pas un écran vide là où l'on
///   avait des chiffres une minute plus tôt ;
/// - la revalidation : son [etag] permet au serveur de répondre 304 sans
///   renvoyer un corps inchangé ;
/// - l'affichage immédiat d'un écran, le temps que le serveur réponde.
///
/// Le cache ne doit jamais faire échouer un appel : toute erreur de stockage
/// ou de chiffrement est avalée, et l'appel se comporte comme sans cache.
class ReponseCache {
  /// Au-delà, une réponse n'est plus servie : mieux vaut un écran d'erreur
  /// que des soldes d'il y a deux mois présentés comme actuels.
  final Duration ageMax;
  final int entreesMax;

  final StockageReponses Function() _ouvrir;
  final ChiffreurCache _chiffreur;
  final DateTime Function() _maintenant;

  StockageReponses? _stockage;
  String? _proprietaireVerifie;
  int _ecrituresDepuisElagage = 0;

  static const _elagageToutesLes = 25;

  ReponseCache({
    StockageReponses? stockage,
    ChiffreurCache? chiffreur,
    DateTime Function()? maintenant,
    this.ageMax = const Duration(days: 30),
    this.entreesMax = 500,
  })  : _ouvrir = (stockage == null ? ouvrirStockage : () => stockage),
        _chiffreur = chiffreur ?? ChiffreurCache.securise(),
        _maintenant = maintenant ?? DateTime.now;

  /// Partagé par tous les clients HTTP de l'application.
  ///
  /// Remplaçable dans les tests des applications (`flutter_test_config.dart`) :
  /// la base SQLite n'y répond pas, une lecture y resterait en suspens.
  static ReponseCache instance = ReponseCache();

  StockageReponses get _base => _stockage ??= _ouvrir();

  /// Enregistre le corps d'une réponse réussie.
  ///
  /// [proprietaire] : identifiant (`sub`) du compte connecté. Le premier
  /// enregistrement d'un nouveau compte efface ce qu'avait laissé le
  /// précédent : un téléphone qui change de mains ne montre pas les données
  /// de l'ancien titulaire.
  Future<void> ecrire(
    String url,
    List<int> corps, {
    String? proprietaire,
    String? etag,
  }) async {
    try {
      final cle = await _chiffreur.hacher(url);
      final contenu = await _chiffreur.chiffrer(corps, cle: cle);
      if (proprietaire != null && proprietaire != _proprietaireVerifie) {
        await _base.supprimerAutresProprietaires(proprietaire);
        _proprietaireVerifie = proprietaire;
      }
      await _base.ecrire(LigneStockee(
        cle: cle,
        proprietaire: proprietaire,
        contenu: contenu,
        enregistreLe: _maintenant(),
        etag: etag,
      ));
      if (++_ecrituresDepuisElagage >= _elagageToutesLes) {
        _ecrituresDepuisElagage = 0;
        await _base.elaguer(
          avant: _maintenant().subtract(ageMax),
          entreesMax: entreesMax,
        );
      }
    } catch (e) {
      debugPrint('tmk_cache : écriture ignorée ($e)');
    }
  }

  /// Dernière réponse enregistrée pour [url], ou `null`.
  ///
  /// Avec [proprietaire], une réponse enregistrée pour un autre compte n'est
  /// pas servie.
  Future<ReponseEnCache?> lire(String url, {String? proprietaire}) async {
    try {
      final ligne = await _servable(url, proprietaire);
      if (ligne == null) return null;
      final corps = await _chiffreur.dechiffrer(ligne.contenu, cle: ligne.cle);
      return ReponseEnCache(corps, ligne.enregistreLe);
    } catch (e) {
      debugPrint('tmk_cache : lecture ignorée ($e)');
      return null;
    }
  }

  /// ETag de la réponse que [lire] servirait, sans la déchiffrer : de quoi
  /// demander au serveur si elle a changé (`If-None-Match`).
  Future<String?> etag(String url, {String? proprietaire}) async {
    try {
      return (await _servable(url, proprietaire))?.etag;
    } catch (e) {
      debugPrint('tmk_cache : lecture ignorée ($e)');
      return null;
    }
  }

  /// Le serveur a répondu 304 : la réponse enregistrée est à jour à cet
  /// instant. Le bandeau hors connexion, s'il la sert plus tard, datera les
  /// données de cette confirmation.
  Future<void> confirmer(String url) async {
    try {
      await _base.confirmer(await _chiffreur.hacher(url), _maintenant());
    } catch (e) {
      debugPrint('tmk_cache : confirmation ignorée ($e)');
    }
  }

  Future<LigneStockee?> _servable(String url, String? proprietaire) async {
    final ligne = await _base.lire(await _chiffreur.hacher(url));
    if (ligne == null) return null;
    if (proprietaire != null && ligne.proprietaire != proprietaire) return null;
    if (_maintenant().difference(ligne.enregistreLe) > ageMax) return null;
    return ligne;
  }

  /// Déconnexion : rien de la session ne doit survivre sur l'appareil.
  Future<void> vider() async {
    _proprietaireVerifie = null;
    try {
      await _base.vider();
    } catch (e) {
      debugPrint('tmk_cache : purge impossible ($e)');
    }
  }
}
