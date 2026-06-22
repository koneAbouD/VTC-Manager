import 'ligne_cotisation.dart';

class LigneCotisationFiltres {
  final int? vehiculeId;
  final int? chauffeurId;
  final StatutLigneCotisation? statut;
  final DateTime? dateDebut;
  final DateTime? dateFin;

  const LigneCotisationFiltres({
    this.vehiculeId,
    this.chauffeurId,
    this.statut,
    this.dateDebut,
    this.dateFin,
  });
}
