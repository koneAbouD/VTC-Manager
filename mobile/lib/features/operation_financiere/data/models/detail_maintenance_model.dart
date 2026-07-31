import '../../domain/entities/detail_maintenance.dart';
import 'element_maintenance_model.dart';

class DetailMaintenanceModel extends DetailMaintenance {
  const DetailMaintenanceModel({
    super.id,
    super.dureeMaintenance,
    super.elements,
  });

  factory DetailMaintenanceModel.fromJson(Map<String, dynamic> json) {
    final elems = (json['elements'] as List<dynamic>? ?? [])
        .map((e) => ElementMaintenanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return DetailMaintenanceModel(
      id: (json['id'] as num?)?.toInt(),
      dureeMaintenance: (json['dureeMaintenance'] as num?)?.toInt(),
      elements: elems,
    );
  }

  Map<String, dynamic> toJson() => {
        if (dureeMaintenance != null) 'dureeMaintenance': dureeMaintenance,
        'elements': elements
            .map((e) => {
                  if (e.catalogueElementId != null)
                    'catalogueElementId': e.catalogueElementId,
                  if (e.libelle != null && e.libelle!.isNotEmpty)
                    'libelle': e.libelle,
                  'quantite': e.quantite,
                  'montant': e.montant,
                  if (e.partenaireId != null) 'partenaireId': e.partenaireId,
                })
            .toList(),
      };
}
