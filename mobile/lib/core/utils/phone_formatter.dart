import 'package:flutter/services.dart';

/// Numéros de téléphone lisibles : l'indicatif reste d'un bloc, le numéro
/// d'abonné se lit par paires — « +225 07 12 34 56 78 ».
///
/// Le regroupement est une affaire d'affichage : ce qui part au serveur reste
/// sans séparateur interne (le rapprochement en base retire de toute façon tout
/// ce qui n'est pas un chiffre, mais deux écritures du même numéro brouillent
/// la recherche locale).
class PhoneFormatter {
  const PhoneFormatter._();

  static const _indicatifCI = '225';

  /// Longueur d'un numéro d'abonné ivoirien. Sert de garde-fou : « 22 51 23 45
  /// 67 » est un numéro local qui commence par 225 sans être préfixé de
  /// l'indicatif — le couper donnerait un faux indicatif.
  static const _longueurLocaleCI = 10;

  static final _nonChiffre = RegExp(r'[^0-9]');

  /// Numéro prêt à afficher. Une saisie vide ou incompréhensible ressort telle
  /// quelle : mieux vaut le numéro brut qu'un regroupement inventé.
  static String format(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '';

    final chiffres = s.replaceAll(_nonChiffre, '');
    if (chiffres.isEmpty) return s;
    final plus = s.startsWith('+');

    // Numéro ivoirien : l'indicatif se détache, le reste se lit par paires.
    if (chiffres.startsWith(_indicatifCI) &&
        chiffres.length > _longueurLocaleCI) {
      final local = chiffres.substring(_indicatifCI.length);
      return '${plus ? '+' : ''}$_indicatifCI ${paires(local)}';
    }

    // Autre pays : l'indicatif ne se devine pas sans table des dial codes. On
    // ne regroupe que ce qui suit le séparateur déjà présent — c'est la forme
    // que produit le formulaire (« +33 612345678 ») — et on laisse le reste
    // intact plutôt que de couper au mauvais endroit.
    if (plus) {
      final espace = s.indexOf(' ');
      return espace > 0
          ? '${s.substring(0, espace)} ${paires(s.substring(espace + 1))}'
          : s;
    }

    return paires(chiffres);
  }

  /// Regroupe une suite de chiffres par paires. Un nombre impair de chiffres
  /// laisse le dernier seul — le numéro est en cours de frappe.
  static String paires(String input) {
    final d = input.replaceAll(_nonChiffre, '');
    if (d.isEmpty) return input.trim();
    final buffer = StringBuffer();
    for (var i = 0; i < d.length; i += 2) {
      if (i > 0) buffer.write(' ');
      buffer.write(d.substring(i, i + 2 > d.length ? d.length : i + 2));
    }
    return buffer.toString();
  }

  /// Le numéro débarrassé de ses séparateurs, tel qu'il doit partir au serveur
  /// et servir aux comparaisons.
  static String chiffres(String? raw) =>
      (raw ?? '').replaceAll(_nonChiffre, '');
}

/// Insère les espaces séparateurs pendant la saisie du numéro d'abonné, sans
/// l'indicatif — celui-ci est choisi à part dans le formulaire.
class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = PhoneFormatter.paires(newValue.text);
    if (formatted == newValue.text) return newValue;

    final cursor = newValue.selection.end;
    if (cursor < 0) {
      return TextEditingValue(text: formatted, selection: newValue.selection);
    }

    // Les espaces insérés décalent le texte : on repère le curseur au nombre de
    // chiffres qui le précèdent, puis on cherche la position équivalente dans
    // le texte regroupé.
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
