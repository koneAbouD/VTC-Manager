enum JourSemaine {
  lundi('LUNDI', 'Lundi', DateTime.monday),
  mardi('MARDI', 'Mardi', DateTime.tuesday),
  mercredi('MERCREDI', 'Mercredi', DateTime.wednesday),
  jeudi('JEUDI', 'Jeudi', DateTime.thursday),
  vendredi('VENDREDI', 'Vendredi', DateTime.friday),
  samedi('SAMEDI', 'Samedi', DateTime.saturday),
  dimanche('DIMANCHE', 'Dimanche', DateTime.sunday);

  final String backend;
  final String label;
  final int weekday;

  const JourSemaine(this.backend, this.label, this.weekday);

  static JourSemaine? fromJson(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    for (final day in JourSemaine.values) {
      if (day.backend == s) return day;
    }
    return null;
  }

  String toJson() => backend;
}
