import '../../domain/entities/element_maintenance.dart';

class ElementMaintenanceModel extends ElementMaintenance {
  const ElementMaintenanceModel({
    super.id,
    super.catalogueElementId,
    super.catalogueElementLibelle,
    super.libelle,
    super.quantite,
    required super.montant,
    super.partenaireId,
    super.partenaireNom,
  });

  factory ElementMaintenanceModel.fromJson(Map<String, dynamic> json) {
    final cat = json['catalogueElement'] as Map<String, dynamic>?;
    return ElementMaintenanceModel(
      id: (json['id'] as num?)?.toInt(),
      catalogueElementId: (cat?['id'] as num?)?.toInt(),
      catalogueElementLibelle: cat?['libelle'] as String?,
      libelle: json['libelle'] as String?,
      // Absente des lignes d'avant la quantité : elles valent un exemplaire.
      quantite: (json['quantite'] as num?)?.toInt() ?? 1,
      montant: (json['montant'] as num).toDouble(),
      partenaireId: (json['partenaireId'] as num?)?.toInt(),
      partenaireNom: json['partenaireNom'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (catalogueElementId != null)
          'catalogueElementId': catalogueElementId,
        if (libelle != null && libelle!.isNotEmpty) 'libelle': libelle,
        'quantite': quantite,
        'montant': montant,
        if (partenaireId != null) 'partenaireId': partenaireId,
      };
}
