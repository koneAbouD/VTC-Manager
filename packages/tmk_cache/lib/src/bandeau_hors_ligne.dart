import 'package:flutter/material.dart';

import 'diagnostic_reseau.dart';
import 'etat_hors_ligne.dart';

/// Bandeau « Hors connexion · données de 14:32 » (ou « Serveur
/// indisponible · … » selon la cause), posé au-dessus de toute
/// l'application (dans `MaterialApp.builder`) tant que des écrans affichent
/// des données du cache.
///
/// L'application reste toujours au même endroit de l'arbre, bandeau visible ou
/// non : la faire changer de parent recréerait le navigateur et perdrait la
/// pile d'écrans. Quand le bandeau est visible, il prend la marge de la barre
/// d'état et l'application ne la réserve plus.
class BandeauHorsLigne extends StatelessWidget {
  final Widget child;
  final Color fond;
  final Color texte;
  final EtatHorsLigne? etat;

  const BandeauHorsLigne({
    super.key,
    required this.child,
    required this.fond,
    required this.texte,
    this.etat,
  });

  @override
  Widget build(BuildContext context) {
    final etatCourant = etat ?? EtatHorsLigne.instance;
    return ValueListenableBuilder<DateTime?>(
      valueListenable: etatCourant,
      builder: (context, depuis, _) {
        final visible = depuis != null;
        final cause = etatCourant.cause;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (visible)
              Material(
                color: fond,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            switch (cause) {
                              CauseIndisponibilite.serveur =>
                                Icons.dns_rounded,
                              CauseIndisponibilite.reseauDesactive =>
                                Icons.signal_wifi_off_rounded,
                              _ => Icons.cloud_off_rounded,
                            },
                            size: 16,
                            color: texte,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              libelleHorsLigne(depuis, DateTime.now(),
                                  cause: cause),
                              style: TextStyle(
                                color: texte,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              key: const ValueKey('application'),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: visible,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Constat selon la cause, puis l'âge des données : « Wi-Fi et données
/// coupés », « Wi-Fi sans internet », « Données mobiles sans internet »,
/// « Hors connexion » (pas d'internet, accès inconnu), « Serveur
/// indisponible » (internet fonctionne) ou « Serveur injoignable » (cause
/// inconnue) — suivi de « · données de 14:32 », « d'hier à 14:32 » ou « du
/// 24/10 à 14:32 ».
String libelleHorsLigne(
  DateTime depuis,
  DateTime maintenant, {
  CauseIndisponibilite cause = CauseIndisponibilite.reseau,
}) {
  String deux(int n) => n.toString().padLeft(2, '0');
  final heure = '${deux(depuis.hour)}:${deux(depuis.minute)}';
  final jour = DateTime(depuis.year, depuis.month, depuis.day);
  final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
  final ecart = aujourdhui.difference(jour).inDays;
  final quand = switch (ecart) {
    0 => 'de $heure',
    1 => "d'hier à $heure",
    _ => 'du ${deux(depuis.day)}/${deux(depuis.month)} à $heure',
  };
  final constat = switch (cause) {
    CauseIndisponibilite.reseauDesactive => 'Wi-Fi et données coupés',
    CauseIndisponibilite.wifiSansInternet => 'Wi-Fi sans internet',
    CauseIndisponibilite.donneesSansInternet => 'Données mobiles sans internet',
    CauseIndisponibilite.reseau => 'Hors connexion',
    CauseIndisponibilite.serveur => 'Serveur indisponible',
    CauseIndisponibilite.inconnue => 'Serveur injoignable',
  };
  return '$constat · données $quand';
}
