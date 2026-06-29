import '../domain/entities/indisponibilite.dart';

/// Logique d'« overlay » des indisponibilités sur les calendriers : on ne se
/// base que sur les dates (début/fin) — le programme n'est jamais muté.
class IndisponibiliteOverlay {
  final List<Indisponibilite> _all;
  const IndisponibiliteOverlay(this._all);

  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  /// Vrai si l'indisponibilité couvre la date.
  static bool couvre(Indisponibilite i, DateTime date) {
    final jour = _d(date);
    final debut = _d(i.dateDebut);
    if (jour.isBefore(debut)) return false;
    if (i.dateFin != null && jour.isAfter(_d(i.dateFin!))) return false;
    return true;
  }

  /// L'indisponibilité qui remplace [chauffeurId] (titulaire) à [date], le cas
  /// échéant. Null si le chauffeur n'est pas indisponible ce jour-là.
  Indisponibilite? remplacementDuTitulaire(int chauffeurId, DateTime date) {
    for (final i in _all) {
      if (i.chauffeurId == chauffeurId &&
          i.chauffeurRemplacantId != null &&
          couvre(i, date)) {
        return i;
      }
    }
    return null;
  }

  /// Vrai si [chauffeurId] est indisponible (titulaire remplacé) à [date].
  bool estIndisponible(int chauffeurId, DateTime date) =>
      remplacementDuTitulaire(chauffeurId, date) != null;

  /// Indisponibilités où [chauffeurId] est le remplaçant assurant le service à
  /// [date] (pour afficher le véhicule récupéré sur son calendrier).
  List<Indisponibilite> remplacementsAssures(int chauffeurId, DateTime date) {
    return _all
        .where((i) =>
            i.chauffeurRemplacantId == chauffeurId && couvre(i, date))
        .toList();
  }
}
