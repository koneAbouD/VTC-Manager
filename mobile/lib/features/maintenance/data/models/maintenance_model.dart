import '../../../operation_financiere/data/models/detail_maintenance_model.dart';
import '../../../operation_financiere/domain/entities/detail_maintenance.dart';
import '../../domain/entities/maintenance.dart';

class MaintenanceModel extends Maintenance {
  const MaintenanceModel({
    super.id,
    required super.type,
    required super.datePrevue,
    super.dateEffectuee,
    super.dureeHeures,
    super.description,
    super.kilometrageAuMoment,
    super.kilometrageProchaine,
    super.cout,
    super.prestataire,
    super.statut,
    super.vehiculeId,
    super.vehiculeNom,
    super.categorieTypeId,
    super.categorieTypeLibelle,
    super.detailMaintenance,
  });

  static String _str(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map) {
      return (v['nom'] ?? v['libelle'] ?? v['code'] ?? v['name'])
              ?.toString() ??
          '';
    }
    return v.toString();
  }

  factory MaintenanceModel.fromJson(Map<String, dynamic> json) {
    final vehiculeJson    = json['vehicule'] as Map<String, dynamic>?;
    final marque          = _str(vehiculeJson?['marque']);
    final modele          = _str(vehiculeJson?['modele']);
    final vehiculeNom     = '$marque $modele'.trim();

    final categorieTypeJson =
        json['categorieType'] as Map<String, dynamic>?;

    return MaintenanceModel(
      id:                  json['id'] as int?,
      type:                json['type'] as String? ?? '',
      datePrevue:          DateTime.parse(json['datePrevue'] as String),
      dateEffectuee:       json['dateEffectuee'] != null
          ? DateTime.parse(json['dateEffectuee'] as String)
          : null,
      dureeHeures:         json['dureeHeures'] as int?,
      description:         json['description'] as String?,
      kilometrageAuMoment: json['kilometrageAuMoment'] as int?,
      kilometrageProchaine: json['kilometrageProchaine'] as int?,
      cout:                json['cout'] != null
          ? (json['cout'] as num).toDouble()
          : null,
      prestataire:         json['prestataire'] as String?,
      statut:              json['statut'] as String?,
      vehiculeId:          vehiculeJson?['id'] as int?,
      vehiculeNom:         vehiculeNom.isEmpty ? null : vehiculeNom,
      categorieTypeId:     categorieTypeJson?['id'] as int?,
      categorieTypeLibelle: categorieTypeJson?['libelle'] as String?,
      detailMaintenance:   json['detailMaintenance'] != null
          ? DetailMaintenanceModel.fromJson(
              json['detailMaintenance'] as Map<String, dynamic>)
          : null,
    );
  }

  factory MaintenanceModel.fromEntity(Maintenance m) => MaintenanceModel(
        id:                  m.id,
        type:                m.type,
        datePrevue:          m.datePrevue,
        dateEffectuee:       m.dateEffectuee,
        dureeHeures:         m.dureeHeures,
        description:         m.description,
        kilometrageAuMoment: m.kilometrageAuMoment,
        kilometrageProchaine: m.kilometrageProchaine,
        cout:                m.cout,
        prestataire:         m.prestataire,
        statut:              m.statut,
        vehiculeId:          m.vehiculeId,
        vehiculeNom:         m.vehiculeNom,
        categorieTypeId:     m.categorieTypeId,
        categorieTypeLibelle: m.categorieTypeLibelle,
        detailMaintenance:   m.detailMaintenance != null
            ? DetailMaintenanceModel(
                id:       m.detailMaintenance!.id,
                elements: m.detailMaintenance!.elements,
              )
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (categorieTypeId != null) 'categorieTypeId': categorieTypeId,
        if (type.isNotEmpty) 'type': type,
        'datePrevue': datePrevue.toIso8601String().substring(0, 10),
        if (dateEffectuee != null)
          'dateEffectuee': dateEffectuee!.toIso8601String().substring(0, 10),
        if (dureeHeures != null) 'dureeHeures': dureeHeures,
        if (description != null) 'description': description,
        if (kilometrageAuMoment != null)
          'kilometrageAuMoment': kilometrageAuMoment,
        if (kilometrageProchaine != null)
          'kilometrageProchaine': kilometrageProchaine,
        if (cout != null) 'cout': cout,
        if (prestataire != null) 'prestataire': prestataire,
        if (statut != null) 'statut': statut,
        if (vehiculeId != null) 'vehiculeId': vehiculeId,
        if (detailMaintenance != null &&
            detailMaintenance!.elements.isNotEmpty)
          'detailMaintenance': _serializeDetail(detailMaintenance!),
      };

  static Map<String, dynamic> _serializeDetail(DetailMaintenance d) => {
        'elements': d.elements
            .map((e) => {
                  if (e.catalogueElementId != null)
                    'catalogueElementId': e.catalogueElementId,
                  if (e.libelle != null && e.libelle!.isNotEmpty)
                    'libelle': e.libelle,
                  'montant': e.montant,
                })
            .toList(),
      };
}
