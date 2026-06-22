import '../enums/document_statut.dart';
import '../enums/type_permis.dart';

/// Permis de conduire — miroir de [PermisConduire] côté backend.
class PermisConduire {
  final int? id;
  final String numero;
  final Set<TypePermis> types;
  final DateTime? dateEmission;
  final DateTime? dateExpiration;
  final DocumentStatut? statut;
  final String? fichierNom;
  final String? fichierUrl;
  final String? fichierType;

  const PermisConduire({
    this.id,
    required this.numero,
    this.types = const <TypePermis>{},
    this.dateEmission,
    this.dateExpiration,
    this.statut,
    this.fichierNom,
    this.fichierUrl,
    this.fichierType,
  });

  bool get isExpire =>
      dateExpiration != null && dateExpiration!.isBefore(DateTime.now());

  PermisConduire copyWith({
    int? id,
    String? numero,
    Set<TypePermis>? types,
    DateTime? dateEmission,
    DateTime? dateExpiration,
    DocumentStatut? statut,
    String? fichierNom,
    String? fichierUrl,
    String? fichierType,
  }) {
    return PermisConduire(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      types: types ?? this.types,
      dateEmission: dateEmission ?? this.dateEmission,
      dateExpiration: dateExpiration ?? this.dateExpiration,
      statut: statut ?? this.statut,
      fichierNom: fichierNom ?? this.fichierNom,
      fichierUrl: fichierUrl ?? this.fichierUrl,
      fichierType: fichierType ?? this.fichierType,
    );
  }
}
