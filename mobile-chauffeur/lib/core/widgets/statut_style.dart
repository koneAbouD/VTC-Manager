import 'package:flutter/material.dart';

/// Couleur + icône associées à un statut, pour la pastille des cartes de liste
/// (charte alignée sur l'app gestionnaire).
(Color, IconData) statutStyle(String? statut) {
  final s = (statut ?? '').toUpperCase();
  return switch (s) {
    'EN_ATTENTE' || 'PLANIFIEE' => (Colors.orange, Icons.hourglass_empty_rounded),
    'PARTIELLEMENT_ENCAISSE' || 'PARTIELLE' || 'PARTIEL' || 'EN_COURS' => (
        Colors.blue,
        Icons.hourglass_top_rounded
      ),
    'ENCAISSE' ||
    'PAYE' ||
    'PAYEE' ||
    'SOLDEE' ||
    'RESTITUEE' ||
    'TERMINEE' =>
      (Colors.green, Icons.check_circle_rounded),
    'ANNULEE' || 'ANNULE' || 'EXPIRE' || 'ECHOUE' => (
        Colors.grey,
        Icons.cancel_rounded
      ),
    _ => (Colors.blueGrey, Icons.info_outline_rounded),
  };
}
