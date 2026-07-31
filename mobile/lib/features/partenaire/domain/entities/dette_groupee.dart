import 'facture_partenaire.dart';

/// Axe de lecture de l'échéancier.
enum VueDette {
  /// Une ligne par intervention : les partenaires qui y sont passés et ce
  /// qu'ils ont fait.
  parMaintenance,

  /// Une ligne par partenaire : tout ce qu'on lui doit, intervention par
  /// intervention.
  parPartenaire;

  String get label => switch (this) {
        parMaintenance => 'Par maintenance',
        parPartenaire => 'Par partenaire',
      };
}

/// Un paquet de dettes vu sous un axe : une intervention et les partenaires
/// qui y sont intervenus, ou un partenaire et tout ce qu'on lui doit.
///
/// Le regroupement se fait ici, pas au serveur : l'échéancier porte déjà sur
/// chaque facture l'intervention d'origine, le partenaire et le détail des
/// éléments — il n'y a rien de plus à demander.
///
/// Un groupe ne se règle jamais : ce sont les factures qu'il contient qui se
/// règlent, une par une. Il ne sert qu'à lire.
class GroupeDette {
  /// Intervention ou partenaire du groupe, selon l'axe. `null` pour le paquet
  /// des dettes qui ne viennent d'aucune intervention.
  final int? id;

  final String titre;

  /// Complément d'identité : l'immatriculation pour une intervention, rien
  /// pour un partenaire. Vide quand il n'y en a pas.
  final String contexte;

  /// Date de l'intervention. Nulle sur l'axe partenaire, où le groupe couvre
  /// plusieurs dates.
  final DateTime? date;

  /// Les dettes du groupe, dans l'ordre de l'échéancier — la plus urgente en
  /// tête.
  final List<FacturePartenaire> factures;

  const GroupeDette({
    required this.id,
    required this.titre,
    required this.contexte,
    required this.date,
    required this.factures,
  });

  double get restantDu => factures.fold<double>(0, (s, f) => s + f.restantDu);

  bool get enRetard => factures.any((f) => f.enRetard);

  /// Le pire retard du groupe : c'est lui qui donne le ton de la ligne.
  int joursDeRetard(DateTime maintenant) => factures
      .map((f) => f.joursDeRetard(maintenant))
      .fold<int>(0, (a, b) => a > b ? a : b);

  /// L'échéance la plus proche, celle qui presse.
  DateTime get prochaineEcheance => factures
      .map((f) => f.dateEcheance)
      .reduce((a, b) => a.isBefore(b) ? a : b);

  /// Nombre de postes couverts, toutes factures du groupe confondues.
  int get nbPostes => factures.fold<int>(0, (s, f) => s + f.lignes.length);

  // ── Regroupements ───────────────────────────────────────────────────────

  static List<GroupeDette> grouper(
    List<FacturePartenaire> factures,
    VueDette vue,
  ) =>
      switch (vue) {
        VueDette.parMaintenance => _parMaintenance(factures),
        VueDette.parPartenaire => _parPartenaire(factures),
      };

  /// Une ligne par intervention. Les dettes nées d'une dépense saisie « à
  /// payer » n'ont pas d'intervention derrière elles : elles se retrouvent
  /// ensemble, plutôt que de faire chacune un groupe d'une seule ligne.
  static List<GroupeDette> _parMaintenance(List<FacturePartenaire> factures) {
    return _paquets(factures, (f) => f.maintenanceId).entries.map((e) {
      final premiere = e.value.first;
      if (e.key == null) {
        return GroupeDette(
          id: null,
          titre: 'Hors intervention',
          contexte: '',
          date: null,
          factures: e.value,
        );
      }
      return GroupeDette(
        id: e.key,
        // La catégorie de l'intervention dit ce qui a été fait ; à défaut, le
        // mot générique vaut mieux qu'un numéro d'identifiant.
        titre: _premierNonVide([premiere.categorieLibelle]) ?? 'Intervention',
        contexte: premiere.vehiculeImmatriculation ?? '',
        date: premiere.dateFacture,
        factures: e.value,
      );
    }).toList();
  }

  /// Une ligne par partenaire, avec tout ce qu'on lui doit.
  static List<GroupeDette> _parPartenaire(List<FacturePartenaire> factures) {
    return _paquets(factures, (f) => f.partenaireId).entries.map((e) {
      final premiere = e.value.first;
      return GroupeDette(
        id: e.key,
        titre: _premierNonVide([premiere.partenaireNom]) ?? 'Partenaire',
        contexte: '',
        date: null,
        factures: e.value,
      );
    }).toList();
  }

  /// Répartit en conservant l'ordre d'arrivée : l'échéancier trie déjà par
  /// urgence, les groupes en héritent sans avoir à retrier.
  static Map<int?, List<FacturePartenaire>> _paquets(
    List<FacturePartenaire> factures,
    int? Function(FacturePartenaire) cle,
  ) {
    final paquets = <int?, List<FacturePartenaire>>{};
    for (final f in factures) {
      (paquets[cle(f)] ??= <FacturePartenaire>[]).add(f);
    }
    return paquets;
  }

  static String? _premierNonVide(List<String?> valeurs) {
    for (final v in valeurs) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}
