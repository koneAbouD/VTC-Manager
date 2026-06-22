import '../../domain/entities/catalogue_element_maintenance.dart';

class CatalogueElementMaintenanceModel extends CatalogueElementMaintenance {
  const CatalogueElementMaintenanceModel({
    required super.id,
    required super.libelle,
    required super.actif,
  });

  factory CatalogueElementMaintenanceModel.fromJson(
      Map<String, dynamic> json) =>
      CatalogueElementMaintenanceModel(
        id: json['id'] as int,
        libelle: json['libelle'] as String,
        actif: json['actif'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {'libelle': libelle};
}
