import 'package:flutter/material.dart';

/// Liste ordonnée des couleurs sélectionnables pour un véhicule.
const List<String> kVehiculeCouleurs = [
  'Blanc',
  'Blanc nacré',
  'Ivoire',
  'Noir',
  'Noir mat',
  'Gris',
  'Gris anthracite',
  'Gris argent',
  'Argent',
  'Champagne',
  'Bleu',
  'Bleu marine',
  'Bleu ciel',
  'Bleu nuit',
  'Rouge',
  'Rouge bordeaux',
  'Rouge cerise',
  'Vert',
  'Vert kaki',
  'Vert olive',
  'Orange',
  'Jaune',
  'Or',
  'Marron',
  'Beige',
  'Sable',
  'Violet',
  'Rose',
];

/// Correspondance nom de couleur -> couleur d'affichage.
const Map<String, Color> kVehiculeCouleurMap = {
  'Blanc': Color(0xFFFFFFFF),
  'Blanc nacré': Color(0xFFF5F0E8),
  'Ivoire': Color(0xFFFFF8DC),
  'Noir': Color(0xFF1A1A1A),
  'Noir mat': Color(0xFF2D2D2D),
  'Gris': Color(0xFF9E9E9E),
  'Gris anthracite': Color(0xFF3D3D3D),
  'Gris argent': Color(0xFFBDBDBD),
  'Argent': Color(0xFFCED4DA),
  'Champagne': Color(0xFFF7E7CE),
  'Bleu': Color(0xFF3B5BDB),
  'Bleu marine': Color(0xFF1B2A6B),
  'Bleu ciel': Color(0xFF74C0FC),
  'Bleu nuit': Color(0xFF0D1B4B),
  'Rouge': Color(0xFFE03131),
  'Rouge bordeaux': Color(0xFF7B1C1C),
  'Rouge cerise': Color(0xFFC0392B),
  'Vert': Color(0xFF2F9E44),
  'Vert kaki': Color(0xFF5C6B2A),
  'Vert olive': Color(0xFF6B7C3A),
  'Orange': Color(0xFFE8590C),
  'Jaune': Color(0xFFFFD43B),
  'Or': Color(0xFFD4A017),
  'Marron': Color(0xFF795548),
  'Beige': Color(0xFFD4A373),
  'Sable': Color(0xFFC2B280),
  'Violet': Color(0xFF7950F2),
  'Rose': Color(0xFFE64980),
};

/// Couleur d'affichage d'un véhicule à partir de son nom de couleur.
/// Renvoie un gris neutre si la couleur est inconnue ou absente.
Color couleurVehicule(String? nom) =>
    kVehiculeCouleurMap[nom] ?? const Color(0xFF9E9E9E);

/// Indique si la couleur est trop claire et nécessite une bordure
/// pour rester visible sur fond blanc.
bool couleurVehiculeEstClaire(Color color) => color.computeLuminance() > 0.85;
