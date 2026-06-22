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
  final String? prestataire;
  final String? statut;
  final int? vehiculeId;
  final String? vehiculeNom;
  final int? categorieTypeId;
  final String? categorieTypeLibelle;
  final DetailMaintenance? detailMaintenance;

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
    this.prestataire,
    this.statut,
    this.vehiculeId,
    this.vehiculeNom,
    this.categorieTypeId,
    this.categorieTypeLibelle,
    this.detailMaintenance,
  });

  bool get isPending => statut == 'PLANIFIEE' || statut == null;
  bool get isDone => statut == 'TERMINEE';

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
    String? prestataire,
    String? statut,
    int? vehiculeId,
    String? vehiculeNom,
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
      prestataire: prestataire ?? this.prestataire,
      statut: statut ?? this.statut,
      vehiculeId: vehiculeId ?? this.vehiculeId,
      vehiculeNom: vehiculeNom ?? this.vehiculeNom,
      categorieTypeId: categorieTypeId ?? this.categorieTypeId,
      categorieTypeLibelle: categorieTypeLibelle ?? this.categorieTypeLibelle,
      detailMaintenance: detailMaintenance ?? this.detailMaintenance,
    );
  }
}
