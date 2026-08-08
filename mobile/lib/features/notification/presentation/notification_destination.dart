import 'package:flutter/material.dart';

import '../../cotisation/presentation/pages/lignes_cotisation_page.dart';
import '../../maintenance/presentation/pages/lignes_maintenance_page.dart';
import '../../recette/presentation/pages/lignes_recette_page.dart';

/// Écran concerné par une notification, ou `null` quand le type n'en désigne
/// aucun.
///
/// Partagé par le routeur push et le centre de notifications : toucher une
/// alerte doit mener au même endroit, qu'elle vienne d'arriver sur le téléphone
/// ou qu'on la relise plus tard dans la liste.
///
/// Le `null` n'est pas un oubli : une version installée depuis longtemps peut
/// recevoir un type qu'elle ne connaît pas encore, et chaque appelant sait quoi
/// en faire — le routeur ouvre le centre, le centre ne bouge pas.
Widget? ecranNotification(String type) => switch (type) {
      'MAINTENANCE_A_VENIR' => const LignesMaintenancePage(),
      'RECETTE_ENCAISSEE' => const LignesRecettePage(),
      'COTISATION_ENCAISSEE' => const LignesCotisationPage(),
      _ => null,
    };
