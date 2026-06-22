import 'ligne_recette.dart';

class LigneRecetteFiltres {
  final int? vehiculeId;
  final int? chauffeurId;
  final StatutLigneRecette? statut;
  final DateTime? dateDebut;
  final DateTime? dateFin;

  const LigneRecetteFiltres({
    this.vehiculeId,
    this.chauffeurId,
    this.statut,
    this.dateDebut,
    this.dateFin,
  });
}
