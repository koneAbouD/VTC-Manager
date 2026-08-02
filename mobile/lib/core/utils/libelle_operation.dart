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
