import '../../../operation_financiere/domain/entities/detail_maintenance.dart';

class Maintenance {
  final int? id;
  final String type;
  final DateTime datePrevue;
  final DateTime? dateEffectuee;
  final int? dureeHeures;
  final String? description;
  final int? kilometrageAuMoment;
  final int? kilometrageProchaine;
  final double? cout;
  /// Partenaire ayant réalisé l'intervention (référentiel des partenaires).
  final int? partenaireId;
  final String? partenaireNom;
  final String? statut;
  final int? vehiculeId;
  final String? vehiculeNom;
  final String? vehiculeImmatriculation;
  final int? categorieTypeId;
  final String? categorieTypeLibelle;
  final DetailMaintenance? detailMaintenance;

  /// Pourquoi l'intervention a été annulée, par qui et quand. Nul tant qu'elle
  /// est au programme.
  final String? motifAnnulation;
  final String? annulePar;
  final DateTime? annuleLe;

  /// Faux si un arrêté — période comptable close, caisse comptée — interdit
  /// désormais la restauration. Le bouton « Restaurer » est alors masqué :
  /// le serveur refuserait.
  final bool restaurable;

  const Maintenance({
    this.id,
    required this.type,
    required this.datePrevue,
    this.dateEffectuee,
    this.dureeHeures,
    this.description,
    this.kilometrageAuMoment,
    this.kilometrageProchaine,
    this.cout,
    this.partenaireId,
    this.partenaireNom,
    this.statut,
    this.vehiculeId,
    this.vehiculeNom,
    this.vehiculeImmatriculation,
    this.categorieTypeId,
    this.categorieTypeLibelle,
    this.detailMaintenance,
    this.motifAnnulation,
    this.annulePar,
    this.annuleLe,
    this.restaurable = false,
  });

  bool get isPending => statut == 'PLANIFIEE' || statut == null;
  bool get isDone => statut == 'TERMINEE';

  /// Une intervention close ne se retouche plus : terminée, son coût et sa date
  /// sont ceux de la dépense déjà passée au journal ; annulée, elle n'a plus
  /// rien à décrire. Le formulaire d'édition leur est fermé — c'est une
  /// nouvelle intervention qu'il faut planifier.
  bool get estModifiable => statut != 'TERMINEE' && statut != 'ANNULEE';

  Maintenance copyWith({
    int? id,
    String? type,
    DateTime? datePrevue,
    DateTime? dateEffectuee,
    int? dureeHeures,
    String? description,
    int? kilometrageAuMoment,
    int? kilometrageProchaine,
    double? cout,
    int? partenaireId,
    String? partenaireNom,
    String? statut,
    int? vehiculeId,
    String? vehiculeNom,
    String? vehiculeImmatriculation,
    int? categorieTypeId,
    String? categorieTypeLibelle,
    DetailMaintenance? detailMaintenance,
  }) {
    return Maintenance(
      id: id ?? this.id,
      type: type ?? this.type,
      datePrevue: datePrevue ?? this.datePrevue,
      dateEffectuee: dateEffectuee ?? this.dateEffectuee,
      dureeHeures: dureeHeures ?? this.dureeHeures,
      description: description ?? this.description,
      kilometrageAuMoment: kilometrageAuMoment ?? this.kilometrageAuMoment,
      kilometrageProchaine: kilometrageProchaine ?? this.kilometrageProchaine,
      cout: cout ?? this.cout,
      partenaireId: partenaireId ?? this.partenaireId,
      partenaireNom: partenaireNom ?? this.partenaireNom,
      statut: statut ?? this.statut,
      vehiculeId: vehiculeId ?? this.vehiculeId,
      vehiculeNom: vehiculeNom ?? this.vehiculeNom,
      vehiculeImmatriculation:
          vehiculeImmatriculation ?? this.vehiculeImmatriculation,
      categorieTypeId: categorieTypeId ?? this.categorieTypeId,
      categorieTypeLibelle: categorieTypeLibelle ?? this.categorieTypeLibelle,
      detailMaintenance: detailMaintenance ?? this.detailMaintenance,
      // Le marquage d'annulation et la restaurabilité ne se saisissent pas :
      // ils viennent du serveur et suivent la copie, sinon une maintenance
      // annulée perdrait son motif au premier copyWith.
      motifAnnulation: motifAnnulation,
      annulePar: annulePar,
      annuleLe: annuleLe,
      restaurable: restaurable,
    );
  }
}
