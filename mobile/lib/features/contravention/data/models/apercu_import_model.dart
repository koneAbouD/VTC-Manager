import 'contravention_model.dart';

/// Aperçu d'un relevé PDF importé (rien n'est encore persisté côté serveur).
class ApercuImportModel {
  final String? plaque;
  final int? vehiculeId;
  final String? vehiculeImmatriculation;
  final bool vehiculeInconnu;
  final String? documentSourcePath;
  final List<ContraventionModel> candidats;
  final List<String> doublonsIgnores;

  const ApercuImportModel({
    this.plaque,
    this.vehiculeId,
    this.vehiculeImmatriculation,
    this.vehiculeInconnu = false,
    this.documentSourcePath,
    this.candidats = const [],
    this.doublonsIgnores = const [],
  });

  factory ApercuImportModel.fromJson(Map<String, dynamic> json) {
    final candidatsJson = (json['candidats'] as List?) ?? const [];
    final doublonsJson = (json['doublonsIgnores'] as List?) ?? const [];
    return ApercuImportModel(
      plaque: json['plaque'] as String?,
      vehiculeId: json['vehiculeId'] as int?,
      vehiculeImmatriculation: json['vehiculeImmatriculation'] as String?,
      vehiculeInconnu: json['vehiculeInconnu'] as bool? ?? false,
      documentSourcePath: json['documentSourcePath'] as String?,
      candidats: candidatsJson
          .map((e) => ContraventionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      doublonsIgnores: doublonsJson.map((e) => e.toString()).toList(),
    );
  }
}
