import '../../domain/entities/catalogue_element_maintenance.dart';

class CatalogueElementMaintenanceModel extends CatalogueElementMaintenance {
  const CatalogueElementMaintenanceModel({
    required super.id,
    required super.libelle,
    required super.actif,
    super.montantDefaut,
    super.imageUrl,
  });

  factory CatalogueElementMaintenanceModel.fromJson(
      Map<String, dynamic> json) =>
      CatalogueElementMaintenanceModel(
        id: json['id'] as int,
        libelle: json['libelle'] as String,
        actif: json['actif'] as bool? ?? true,
        montantDefaut: (json['montantDefaut'] as num?)?.toDouble(),
        imageUrl: json['imageUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {'libelle': libelle};
}
