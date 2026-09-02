import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../utils/amount_input_formatter.dart';

/// Saisie d'un montant en francs, et les refus qui vont avec.
///
/// Toutes les feuilles d'encaissement passent par ici : le guichet doit voir
/// le même champ et lire les mêmes messages, qu'il solde une créance, deux
/// lignes du même jour ou un lot entier. Les montants s'écrivent avec leurs
/// séparateurs de milliers dès la frappe — « 125 000 » se relit d'un coup
/// d'œil, « 125000 » se recompte.

final _money = NumberFormat('#,##0', 'fr_FR');

/// Le clavier ne rend que des chiffres et un séparateur décimal : ni signe,
/// ni lettre, ni second séparateur. Ce qui est refusé ici n'a pas besoin d'un
/// message — le caractère n'apparaît simplement pas.
final _caracteresAutorises =
    FilteringTextInputFormatter.allow(RegExp(r'[0-9   .,]'));

/// Lit un montant saisi : espaces de milliers (ordinaires ou insécables) et
/// virgule décimale du clavier français. `null` si ce n'est pas un nombre.
double? parseMontant(String? texte) {
  if (texte == null) return null;
  final brut = texte
      .replaceAll(RegExp(r'[\s  ]'), '')
      .replaceAll(',', '.');
  if (brut.isEmpty) return null;
  return double.tryParse(brut);
}

/// Écrit un montant dans un champ de saisie : séparateurs de milliers, et pas
/// de décimales inutiles.
String formatMontantSaisie(double montant) {
  final brut = montant == montant.roundToDouble()
      ? montant.toStringAsFixed(0)
      : montant.toStringAsFixed(2);
  return AmountInputFormatter.format(brut);
}

/// « 15 000 XOF »
String formatMontantCourt(double montant) => '${_money.format(montant)} XOF';

/// Refus communs à toutes les saisies de montant, formulés pour l'écran.
///
/// [plafond] est ce que la ou les créances visées peuvent encore recevoir :
/// au-delà, le serveur refuserait l'écriture, autant le dire tout de suite.
/// [autoriseVide] sert aux lots, où effacer un montant est la façon d'écarter
/// une ligne sans la décocher.
String? validerMontant(
  String? valeur, {
  required double? plafond,
  bool autoriseVide = false,
  String libellePlafond = 'le montant restant',
  String Function(double plafond)? messageDepassement,
}) {
  final texte = valeur?.trim() ?? '';
  if (texte.isEmpty) return autoriseVide ? null : 'Montant obligatoire';

  final montant = parseMontant(texte);
  if (montant == null) return 'Montant invalide';
  if (montant < 0) return 'Montant négatif';
  if (montant == 0) return autoriseVide ? null : 'Le montant doit être positif';

  if (plafond != null && montant > plafond) {
    return messageDepassement?.call(plafond) ??
        'Dépasse $libellePlafond (${formatMontantCourt(plafond)})';
  }
  return null;
}

/// Champ de saisie d'un montant, contrôlé à la frappe.
class MontantField extends StatelessWidget {
  final TextEditingController controller;

  /// Ce que la ou les créances visées peuvent encore recevoir. `null` quand il
  /// n'y a pas de plafond connu (recette sans montant attendu).
  final double? plafond;

  final bool autoriseVide;
  final String libellePlafond;

  /// Message de dépassement sur mesure, pour les champs trop étroits pour une
  /// phrase entière.
  final String Function(double plafond)? messageDepassement;

  final bool enabled;

  /// Décoration de la feuille appelante : chaque sheet a la sienne.
  final InputDecoration decoration;

  final TextAlign textAlign;
  final TextStyle? style;

  const MontantField({
    super.key,
    required this.controller,
    required this.plafond,
    required this.decoration,
    this.autoriseVide = false,
    this.libellePlafond = 'le montant restant',
    this.messageDepassement,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_caracteresAutorises, const AmountInputFormatter()],
      textAlign: textAlign,
      style: style,
      decoration: decoration,
      // Le dépassement se voit pendant la frappe : découvrir à la validation
      // qu'on a tapé un zéro de trop oblige à tout relire.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) => validerMontant(
        v,
        plafond: plafond,
        autoriseVide: autoriseVide,
        libellePlafond: libellePlafond,
        messageDepassement: messageDepassement,
      ),
    );
  }
}
