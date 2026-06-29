import '../../domain/entities/indisponibilite.dart';

class IndisponibiliteModel extends Indisponibilite {
  const IndisponibiliteModel({
    super.id,
    required super.chauffeurId,
    super.chauffeurNom,
    super.chauffeurRemplacantId,
    super.chauffeurRemplacantNom,
    required super.dateDebut,
    super.dateFin,
    super.motif,
    super.commentaire,
    super.statut,
  });

  static String? _nomFrom(Map<String, dynamic>? c) {
    if (c == null) return null;
    final nom = '${c['prenom'] ?? ''} ${c['nom'] ?? ''}'.trim();
    return nom.isEmpty ? null : nom;
  }

  factory IndisponibiliteModel.fromJson(Map<String, dynamic> json) {
    final chauffeur = json['chauffeur'] as Map<String, dynamic>?;
    final remplacant = json['chauffeurRemplacant'] as Map<String, dynamic>?;
    return IndisponibiliteModel(
      id: json['id'] as int?,
      chauffeurId: chauffeur?['id'] as int? ?? 0,
      chauffeurNom: _nomFrom(chauffeur),
      chauffeurRemplacantId: remplacant?['id'] as int?,
      chauffeurRemplacantNom: _nomFrom(remplacant),
      dateDebut: DateTime.parse(json['dateDebut'] as String),
      dateFin: json['dateFin'] != null
          ? DateTime.parse(json['dateFin'] as String)
          : null,
      motif: json['motif'] as String?,
      commentaire: json['commentaire'] as String?,
      statut: json['statut'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'chauffeurId': chauffeurId,
        if (chauffeurRemplacantId != null)
          'chauffeurRemplacantId': chauffeurRemplacantId,
        'dateDebut': dateDebut.toIso8601String().substring(0, 10),
        if (dateFin != null)
          'dateFin': dateFin!.toIso8601String().substring(0, 10),
        if (motif != null) 'motif': motif,
        if (commentaire != null) 'commentaire': commentaire,
      };
}
