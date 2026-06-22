import '../../domain/entities/element_maintenance.dart';

class ElementMaintenanceModel extends ElementMaintenance {
  const ElementMaintenanceModel({
    super.id,
    super.catalogueElementId,
    super.catalogueElementLibelle,
    super.libelle,
    required super.montant,
  });

  factory ElementMaintenanceModel.fromJson(Map<String, dynamic> json) {
    final cat = json['catalogueElement'] as Map<String, dynamic>?;
    return ElementMaintenanceModel(
      id: (json['id'] as num?)?.toInt(),
      catalogueElementId: (cat?['id'] as num?)?.toInt(),
      catalogueElementLibelle: cat?['libelle'] as String?,
      libelle: json['libelle'] as String?,
      montant: (json['montant'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (catalogueElementId != null) 'catalogueElementId': catalogueElementId,
        if (libelle != null && libelle!.isNotEmpty) 'libelle': libelle,
        'montant': montant,
      };
}
