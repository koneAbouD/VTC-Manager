import 'package:intl/intl.dart';

/// Formateurs de dates partagés dans toute l'application.
class DateFormatter {
  DateFormatter._();

  static final _short = DateFormat('dd/MM/yyyy');
  static final _monthYear = DateFormat('MMMM yyyy', 'fr_FR');
  static final _monthOnly = DateFormat('MMMM', 'fr_FR');
  static final _dayMonth = DateFormat('d MMM', 'fr_FR');

  /// 12/04/2025
  static String short(DateTime date) => _short.format(date);

  /// Avril 2025
  static String monthYear(DateTime date) => _monthYear.format(date);

  /// Avril
  static String monthOnly(DateTime date) => _monthOnly.format(date);

  /// 12 Avr
  static String dayMonth(DateTime date) => _dayMonth.format(date);

  /// Conversion ISO8601 → date only (YYYY-MM-DD)
  static String toIsoDate(DateTime date) =>
      date.toIso8601String().substring(0, 10);
}
