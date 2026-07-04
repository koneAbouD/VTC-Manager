/// Compte de trésorerie avec son solde courant
/// (solde initial + somme des opérations non annulées).
class CompteTresorerie {
  final int id;
  final String code;
  final String libelle;

  /// CAISSE | MOBILE_MONEY | BANQUE
  final String type;
  final String? operateur;
  final double soldeInitial;
  final bool parDefaut;
  final bool actif;
  final double solde;

  const CompteTresorerie({
    required this.id,
    required this.code,
    required this.libelle,
    required this.type,
    this.operateur,
    required this.soldeInitial,
    required this.parDefaut,
    required this.actif,
    required this.solde,
  });

  factory CompteTresorerie.fromJson(Map<String, dynamic> j) => CompteTresorerie(
        id: (j['id'] as num).toInt(),
        code: j['code'] ?? '',
        libelle: j['libelle'] ?? '',
        type: j['type'] ?? 'CAISSE',
        operateur: j['operateur'],
        soldeInitial: (j['soldeInitial'] as num?)?.toDouble() ?? 0,
        parDefaut: j['parDefaut'] ?? false,
        actif: j['actif'] ?? true,
        solde: (j['solde'] as num?)?.toDouble() ?? 0,
      );
}

/// Réponse de GET /comptes-tresorerie : comptes + total + dette État.
class TresorerieSummary {
  final List<CompteTresorerie> comptes;
  final double totalTresorerie;

  /// Contraventions encaissées auprès des chauffeurs, non reversées à l'État.
  final double aReverserEtat;

  const TresorerieSummary({
    required this.comptes,
    required this.totalTresorerie,
    required this.aReverserEtat,
  });

  factory TresorerieSummary.fromJson(Map<String, dynamic> j) =>
      TresorerieSummary(
        comptes: (j['comptes'] as List? ?? [])
            .map((e) => CompteTresorerie.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalTresorerie: (j['totalTresorerie'] as num?)?.toDouble() ?? 0,
        aReverserEtat: (j['aReverserEtat'] as num?)?.toDouble() ?? 0,
      );
}
