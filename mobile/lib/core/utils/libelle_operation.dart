// Libellés partagés des lignes d'opération financière : le titre affiché sur
// l'Accueil, la liste des opérations et le rapport financier doit être le
// même, alors que ces trois écrans ne manipulent pas la même entité.

/// Codes des catégories d'encaissement (recette / cotisation / pénalité).
/// Seules ces opérations portent la date relative dans leur libellé : elles
/// règlent une période passée, alors qu'une dépense se lit à sa date de saisie.
const kCodesCategorieEncaissement = {
  'ENCAISSEMENT_RECETTES',
  'ENCAISSEMENT_COTISATIONS',
  'ENCAISSEMENT_PENALITES',
};

bool estCategorieEncaissement(String? categorieCode) =>
    kCodesCategorieEncaissement.contains(categorieCode?.toUpperCase());

/// Ce qu'un encaissement a soldé, dit au chauffeur : « Recette du 10/09/2026 ».
///
/// Le libellé comptable de la catégorie — « Encaissement recettes » — nomme le
/// geste du guichet, pas la dette du chauffeur : sur un reçu qui lui est
/// destiné, c'est la créance qu'il faut nommer. Une catégorie inconnue retombe
/// sur [categorieLibelle], qui reste préférable à un reçu muet.
String libelleCreanceEncaissee({
  required String? categorieCode,
  required String? categorieLibelle,
  required DateTime date,
}) {
  String deux(int n) => n.toString().padLeft(2, '0');
  final jour = '${deux(date.day)}/${deux(date.month)}/${date.year}';
  final nature = switch (categorieCode?.toUpperCase()) {
    'ENCAISSEMENT_RECETTES' => 'Recette',
    'ENCAISSEMENT_COTISATIONS' => 'Cotisation',
    'ENCAISSEMENT_PENALITES' => 'Pénalité',
    _ => categorieLibelle,
  };
  return nature == null ? 'Versement du $jour' : '$nature du $jour';
}

/// Connecteur de date relatif, recalculé à CHAQUE affichage (donc « hier »
/// devient « avant-hier » le lendemain, etc.) — aucune tâche planifiée requise :
///   aujourd'hui   → "d'aujourd'hui"
///   hier          → "d'hier"
///   avant-hier    → "d'avant-hier"
///   au-delà       → "du JJ/MM/AAAA"
/// Destiné à suffixer un libellé, ex. « Encaissement recettes d'hier ».
String libelleDateRelative(DateTime date) {
  final jour = DateTime(date.year, date.month, date.day);
  final maintenant = DateTime.now();
  final aujourdhui =
      DateTime(maintenant.year, maintenant.month, maintenant.day);
  final ecartJours = aujourdhui.difference(jour).inDays;
  String deux(int n) => n.toString().padLeft(2, '0');
  return switch (ecartJours) {
    0 => "d'aujourd'hui",
    1 => "d'hier",
    2 => "d'avant-hier",
    _ => 'du ${deux(date.day)}/${deux(date.month)}/${date.year}',
  };
}

/// Titre d'une ligne d'opération : « Catégorie d'hier » pour un encaissement,
/// « Catégorie » seul sinon (pas de date pour les autres opérations).
/// [date] est la date métier de l'opération (période réglée).
String libelleLigneOperation({
  required String? categorieCode,
  required String categorie,
  required DateTime date,
}) =>
    estCategorieEncaissement(categorieCode)
        ? '$categorie ${libelleDateRelative(date)}'
        : categorie;
