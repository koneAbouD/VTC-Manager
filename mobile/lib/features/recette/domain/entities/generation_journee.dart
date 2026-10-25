/// Bilan de la génération d'une journée : recettes et cotisations d'un seul
/// geste (`POST /recettes/lignes/generer-avec-cotisations`).
///
/// Les deux côtés sont indépendants : l'échec de l'un n'emporte pas l'autre, et
/// chaque erreur est rédigée côté serveur pour être affichée telle quelle. Les
/// compteurs incluent les lignes déjà présentes remises à jour : la génération
/// est idempotente, relancer la même journée ne crée aucun doublon.
class GenerationJournee {
  final DateTime date;
  final int recettes;
  final String? erreurRecettes;
  final int cotisations;
  final String? erreurCotisations;

  const GenerationJournee({
    required this.date,
    required this.recettes,
    this.erreurRecettes,
    required this.cotisations,
    this.erreurCotisations,
  });

  factory GenerationJournee.fromJson(Map<String, dynamic> json) =>
      GenerationJournee(
        date: DateTime.parse(json['date'] as String),
        recettes: json['recettes'] as int? ?? 0,
        erreurRecettes: json['erreurRecettes'] as String?,
        cotisations: json['cotisations'] as int? ?? 0,
        erreurCotisations: json['erreurCotisations'] as String?,
      );

  bool get recettesReussies => erreurRecettes == null;
  bool get cotisationsReussies => erreurCotisations == null;

  /// Au moins un des deux côtés a échoué : le message s'affiche en erreur.
  bool get enErreur => !recettesReussies || !cotisationsReussies;

  /// Message du snackbar : un verdict par côté.
  String get message {
    final recette = recettesReussies
        ? _compte(recettes, 'recette', 'recettes')
        : 'Recettes : $erreurRecettes';
    final cotisation = cotisationsReussies
        ? _compte(cotisations, 'cotisation', 'cotisations')
        : 'Cotisations : $erreurCotisations';
    if (!enErreur) return "Lignes d'hier générées : $recette, $cotisation.";
    return '$recette\n$cotisation';
  }

  static String _compte(int n, String singulier, String pluriel) => switch (n) {
        0 => 'aucune $singulier due',
        1 => '1 $singulier',
        _ => '$n $pluriel',
      };
}
