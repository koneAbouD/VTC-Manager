import 'package:flutter/material.dart';

import 'etat_hors_ligne.dart';

/// Bandeau « Hors connexion · données de 14:32 », posé au-dessus de toute
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
    return ValueListenableBuilder<DateTime?>(
      valueListenable: etat ?? EtatHorsLigne.instance,
      builder: (context, depuis, _) {
        final visible = depuis != null;
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
                          Icon(Icons.cloud_off_rounded, size: 16, color: texte),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              libelleHorsLigne(depuis, DateTime.now()),
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

/// « Hors connexion · données de 14:32 », « d'hier à 14:32 » ou
/// « du 24/10 à 14:32 ».
String libelleHorsLigne(DateTime depuis, DateTime maintenant) {
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
  return 'Hors connexion · données $quand';
}
