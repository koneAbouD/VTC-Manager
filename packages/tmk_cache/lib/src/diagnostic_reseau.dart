import 'package:connectivity_plus/connectivity_plus.dart';

import '_diagnostic_io.dart' if (dart.library.js_interop) '_diagnostic_web.dart'
    as plateforme;

/// Pourquoi le serveur n'a pas répondu — ce que l'utilisateur doit faire en
/// dépend : activer le Wi-Fi ou les données, vérifier sa box, ou patienter.
enum CauseIndisponibilite {
  /// Ni Wi-Fi ni données mobiles actifs (désactivés, mode avion).
  reseauDesactive,

  /// Connecté à un Wi-Fi qui n'atteint pas internet (box, portail).
  wifiSansInternet,

  /// Données mobiles actives mais sans internet (réseau faible, forfait
  /// épuisé).
  donneesSansInternet,

  /// Pas d'internet, sans plus de précision sur l'accès.
  reseau,

  /// Internet fonctionne, le serveur ne répond pas (arrêt, maintenance).
  serveur,

  /// Impossible à trancher (web, sonde impossible).
  inconnue;

  /// Le problème est du côté du téléphone (accès, réseau), pas du serveur.
  bool get estReseau => switch (this) {
        reseauDesactive || wifiSansInternet || donneesSansInternet || reseau =>
          true,
        serveur || inconnue => false,
      };
}

/// Accès réseau actif sur le téléphone.
enum AccesReseau { aucun, wifi, donneesMobiles, autre, inconnu }

/// Trouve la cause d'un échec de connexion au serveur.
///
/// Dans l'ordre :
/// 1. une connexion **refusée** vient d'une machine qui répond : c'est le
///    serveur, quel que soit l'accès ;
/// 2. aucun accès actif (Wi-Fi et données coupés) : inutile de sonder ;
/// 3. un réseau **injoignable** : pas d'internet sur l'accès actif ;
/// 4. le reste — délai dépassé, connexion coupée, échec DNS — est tranché par
///    une sonde : une connexion TCP vers 1.1.1.1:443 (DNS public de
///    Cloudflare), sans rien y envoyer. Si elle aboutit, internet fonctionne
///    et c'est le serveur qui manque.
///
/// Côté réseau, l'accès actif précise la cause : Wi-Fi sans internet, ou
/// données mobiles sans internet.
///
/// Le résultat de la sonde est retenu quelques secondes : quand plusieurs
/// écrans échouent ensemble, une seule sonde part.
class DiagnosticReseau {
  final Future<bool?> Function() _sonde;
  final Future<AccesReseau> Function() _acces;
  final Duration _memoire;
  final DateTime Function() _maintenant;

  Future<bool?>? _sondeEnCours;
  bool? _dernierResultat;
  DateTime? _sondeLe;

  DiagnosticReseau({
    Future<bool?> Function()? sonde,
    Future<AccesReseau> Function()? acces,
    Duration memoire = const Duration(seconds: 10),
    DateTime Function()? maintenant,
  })  : _sonde = sonde ?? plateforme.sonderInternet,
        _acces = acces ?? accesActif,
        _memoire = memoire,
        _maintenant = maintenant ?? DateTime.now;

  /// Partagé par les clients HTTP de l'application. Remplaçable dans les
  /// tests (`flutter_test_config.dart`) : la vraie sonde sortirait sur
  /// internet.
  static DiagnosticReseau instance = DiagnosticReseau();

  /// Cause de [erreur], levée par le client HTTP (exception système, délai
  /// dépassé…).
  Future<CauseIndisponibilite> causeDe(Object erreur) async {
    final systeme = plateforme.causeCertaine(erreur);
    if (systeme == CauseIndisponibilite.serveur) {
      return CauseIndisponibilite.serveur;
    }

    final acces = await _accesSansEchec();
    if (acces == AccesReseau.aucun) return CauseIndisponibilite.reseauDesactive;
    if (systeme == CauseIndisponibilite.reseau) return _sansInternet(acces);

    return switch (await _internetFonctionne()) {
      true => CauseIndisponibilite.serveur,
      false => _sansInternet(acces),
      null => CauseIndisponibilite.inconnue,
    };
  }

  static CauseIndisponibilite _sansInternet(AccesReseau acces) =>
      switch (acces) {
        AccesReseau.wifi => CauseIndisponibilite.wifiSansInternet,
        AccesReseau.donneesMobiles => CauseIndisponibilite.donneesSansInternet,
        _ => CauseIndisponibilite.reseau,
      };

  Future<AccesReseau> _accesSansEchec() async {
    try {
      return await _acces();
    } catch (_) {
      return AccesReseau.inconnu;
    }
  }

  Future<bool?> _internetFonctionne() {
    final le = _sondeLe;
    if (le != null && _maintenant().difference(le) < _memoire) {
      return Future.value(_dernierResultat);
    }
    return _sondeEnCours ??= _sonde().then((resultat) {
      _dernierResultat = resultat;
      _sondeLe = _maintenant();
      return resultat;
    }, onError: (Object _) => null).whenComplete(() => _sondeEnCours = null);
  }
}

/// Accès actif selon le système. Wi-Fi et données à la fois : le système
/// passe par le Wi-Fi, c'est lui qui est en cause.
Future<AccesReseau> accesActif() async =>
    accesDepuis(await Connectivity().checkConnectivity());

/// Lecture des accès remontés par connectivity_plus.
AccesReseau accesDepuis(List<ConnectivityResult> resultats) {
  if (resultats.isEmpty ||
      resultats.every((r) => r == ConnectivityResult.none)) {
    return AccesReseau.aucun;
  }
  if (resultats.contains(ConnectivityResult.wifi)) return AccesReseau.wifi;
  if (resultats.contains(ConnectivityResult.mobile)) {
    return AccesReseau.donneesMobiles;
  }
  return AccesReseau.autre;
}
