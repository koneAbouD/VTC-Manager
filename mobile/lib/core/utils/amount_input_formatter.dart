import 'package:flutter/services.dart';

/// Insère des espaces séparateurs de milliers dans un montant, à l'affichage
/// comme pendant la saisie.
///
/// Seule la partie entière est regroupée : le signe et la partie décimale
/// (séparateur `,` ou `.`) sont laissés tels quels. Une saisie qui n'est pas
/// un nombre est retournée inchangée, la validation du formulaire s'en charge.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter();

  static final _numberRe = RegExp(r'^(-?)(\d*)([.,]\d*)?$');
  static final _groupRe = RegExp(r'(\d)(?=(\d{3})+$)');

  /// Regroupe la partie entière de [input] par tranches de trois chiffres.
  static String format(String input) {
    final raw = input.replaceAll(' ', '');
    final match = _numberRe.firstMatch(raw);
    if (match == null) return input;
    final sign = match.group(1)!;
    final entier = match.group(2)!;
    final decimales = match.group(3) ?? '';
    return '$sign${entier.replaceAllMapped(_groupRe, (m) => '${m[1]} ')}$decimales';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);
    if (formatted == newValue.text) return newValue;

    final cursor = newValue.selection.end;
    if (cursor < 0) {
      return TextEditingValue(text: formatted, selection: newValue.selection);
    }

    // Les espaces ajoutés décalent le texte : on repère le curseur au nombre
    // de caractères significatifs qui le précèdent, puis on cherche la position
    // équivalente dans le texte regroupé.
    var significatifs = 0;
    for (var i = 0; i < cursor && i < newValue.text.length; i++) {
      if (newValue.text[i] != ' ') significatifs++;
    }

    var offset = 0;
    if (significatifs > 0) {
      offset = formatted.length;
      var vus = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (formatted[i] != ' ') vus++;
        if (vus == significatifs) {
          offset = i + 1;
          break;
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
