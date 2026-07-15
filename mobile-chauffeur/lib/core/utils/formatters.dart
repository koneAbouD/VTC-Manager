import 'package:intl/intl.dart';

/// Formatage monétaire (FCFA) et dates, cohérent dans toute l'app.
class Fmt {
  static final _money = NumberFormat.decimalPattern('fr');
  static final _date = DateFormat('dd/MM/yyyy', 'fr');

  /// Ex. « 12 500 FCFA ». Accepte num, String ou null.
  static String money(dynamic value) {
    final n = _toNum(value);
    if (n == null) return '—';
    return '${_money.format(n)} FCFA';
  }

  static String date(dynamic value) {
    if (value == null) return '—';
    final d = value is DateTime ? value : DateTime.tryParse(value.toString());
    return d == null ? '—' : _date.format(d);
  }

  static num? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }
}
