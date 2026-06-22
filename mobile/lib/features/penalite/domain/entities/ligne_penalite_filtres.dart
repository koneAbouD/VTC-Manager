import 'ligne_penalite.dart';

class LignePenaliteFiltres {
  final int? vehiculeId;
  final int? chauffeurId;
  final TypeSanctionLigne? typeSanction;
  final StatutLignePenalite? statut;
  final DateTime? dateDebut;
  final DateTime? dateFin;

  const LignePenaliteFiltres({
    this.vehiculeId,
    this.chauffeurId,
    this.typeSanction,
    this.statut,
    this.dateDebut,
    this.dateFin,
  });
}
