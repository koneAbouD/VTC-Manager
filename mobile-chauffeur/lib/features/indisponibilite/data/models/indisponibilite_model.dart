import '../../domain/entities/indisponibilite.dart';

class IndisponibiliteModel extends Indisponibilite {
  const IndisponibiliteModel({
    super.id,
    super.dateDebut,
    super.dateFin,
    super.motif,
    super.commentaire,
    super.statut,
    super.remplacantNom,
  });

  factory IndisponibiliteModel.fromJson(Map<String, dynamic> j) {
    final rempl = j['chauffeurRemplacant'] as Map?;
    final remplNom = rempl == null
        ? null
        : '${rempl['prenom'] ?? ''} ${rempl['nom'] ?? ''}'.trim();
    return IndisponibiliteModel(
      id: j['id'] as int?,
      dateDebut: j['dateDebut'] as String?,
      dateFin: j['dateFin'] as String?,
      motif: j['motif'] as String?,
      commentaire: j['commentaire'] as String?,
      statut: j['statut'] as String?,
      remplacantNom: (remplNom == null || remplNom.isEmpty) ? null : remplNom,
    );
  }
}
