import '../../domain/entities/permis_conduire.dart';
import '../../domain/enums/document_statut.dart';
import '../../domain/enums/type_permis.dart';

class PermisConduireModel extends PermisConduire {
  const PermisConduireModel({
    super.id,
    required super.numero,
    super.types,
    super.dateEmission,
    super.dateExpiration,
    super.statut,
    super.fichierNom,
    super.fichierUrl,
    super.fichierType,
  });

  factory PermisConduireModel.fromJson(Map<String, dynamic> json) {
    return PermisConduireModel(
      id: json['id'] as int?,
      numero: (json['numero'] as String?) ?? '',
      types: TypePermis.setFromJson(json['types']),
      dateEmission: json['dateEmission'] != null
          ? DateTime.tryParse(json['dateEmission'] as String)
          : null,
      dateExpiration: json['dateExpiration'] != null
          ? DateTime.tryParse(json['dateExpiration'] as String)
          : null,
      statut: DocumentStatut.fromJson(json['statut']),
      fichierNom: json['fichierNom'] as String?,
      fichierUrl: json['fichierUrl'] as String?,
      fichierType: json['fichierType'] as String?,
    );
  }
}
