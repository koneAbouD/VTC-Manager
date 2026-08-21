import 'ligne_cotisation.dart';

/// Cumuls d'un statut sur la sélection courante.
class TotalStatutCotisation {
  final StatutLigneCotisation statut;
  final int nombre;
  final double montantDu;
  final double montantEncaisse;

  const TotalStatutCotisation({
    required this.statut,
    required this.nombre,
    required this.montantDu,
    required this.montantEncaisse,
  });

  factory TotalStatutCotisation.fromJson(Map<String, dynamic> j) =>
      TotalStatutCotisation(
        statut: StatutLigneCotisation.fromJson(j['statut'] as String),
        nombre: (j['nombre'] as num?)?.toInt() ?? 0,
        montantDu: (j['montantDu'] as num?)?.toDouble() ?? 0,
        montantEncaisse: (j['montantEncaisse'] as num?)?.toDouble() ?? 0,
      );
}

/// Cumuls de la sélection de lignes de cotisation, calculés par le serveur.
///
/// La liste étant paginée, additionner ce que le scroll a chargé donnait un
/// total qui grandissait à mesure qu'on descendait : sur un mois de 300 lignes,
/// les pastilles annonçaient les 20 premières. Ces montants portent sur toute la
/// sélection, quel que soit ce qui est affiché.
class TotauxCotisation {
  final int nombre;
  final double montantDu;
  final double montantEncaisse;
  final List<TotalStatutCotisation> parStatut;

  const TotauxCotisation({
    required this.nombre,
    required this.montantDu,
    required this.montantEncaisse,
    required this.parStatut,
  });

  static const vide = TotauxCotisation(
      nombre: 0, montantDu: 0, montantEncaisse: 0, parStatut: []);

  /// Montants dus indexés par statut, la clé `null` portant le total : la forme
  /// qu'attendent les pastilles de l'écran.
  Map<StatutLigneCotisation?, double> get montantsDus => {
        null: montantDu,
        for (final t in parStatut) t.statut: t.montantDu,
      };

  factory TotauxCotisation.fromJson(Map<String, dynamic> j) => TotauxCotisation(
        nombre: (j['nombre'] as num?)?.toInt() ?? 0,
        montantDu: (j['montantDu'] as num?)?.toDouble() ?? 0,
        montantEncaisse: (j['montantEncaisse'] as num?)?.toDouble() ?? 0,
        parStatut: ((j['parStatut'] as List?) ?? [])
            .map((e) => TotalStatutCotisation.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
