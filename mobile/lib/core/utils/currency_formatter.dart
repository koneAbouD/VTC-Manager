import 'package:intl/intl.dart';

/// Formateur monétaire XOF partagé dans toute l'application.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _fmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'XOF',
    decimalDigits: 0,
  );

  static String format(num amount) => _fmt.format(amount);
}
