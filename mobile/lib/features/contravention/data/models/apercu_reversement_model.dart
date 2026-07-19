/// Aperçu d'une quittance de paiement de l'État importée (rien n'est encore
/// reversé côté serveur). Renvoyé par `POST /contraventions/reversements/importer`.
class ApercuReversementModel {
  final String? numeroLiquidation;
  final String? numeroDemande;
  final String? demandeur;
  final DateTime? dateQuittance;
  final String? documentSourcePath;
  final int nombreAReverser;
  final double totalAReverser;
  final List<LigneReversementModel> lignes;

  const ApercuReversementModel({
    this.numeroLiquidation,
    this.numeroDemande,
    this.demandeur,
    this.dateQuittance,
    this.documentSourcePath,
    this.nombreAReverser = 0,
    this.totalAReverser = 0,
    this.lignes = const [],
  });

  /// Référence quittance à tracer sur les opérations (liquidation à défaut demande).
  String? get referenceAudit =>
      (numeroLiquidation != null && numeroLiquidation!.isNotEmpty)
          ? numeroLiquidation
          : numeroDemande;

  factory ApercuReversementModel.fromJson(Map<String, dynamic> json) {
    final lignesJson = (json['lignes'] as List?) ?? const [];
    return ApercuReversementModel(
      numeroLiquidation: json['numeroLiquidation'] as String?,
      numeroDemande: json['numeroDemande'] as String?,
      demandeur: json['demandeur'] as String?,
      dateQuittance: json['dateQuittance'] != null
          ? DateTime.tryParse(json['dateQuittance'] as String)
          : null,
      documentSourcePath: json['documentSourcePath'] as String?,
      nombreAReverser: (json['nombreAReverser'] as num?)?.toInt() ?? 0,
      totalAReverser: (json['totalAReverser'] as num?)?.toDouble() ?? 0,
      lignes: lignesJson
          .map((e) => LigneReversementModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Classement d'une ligne de quittance après rapprochement en base.
enum StatutLigneReversement { aReverser, dejaReversee, introuvable, inconnu }

StatutLigneReversement _statutFrom(String? v) {
  switch (v) {
    case 'A_REVERSER':
      return StatutLigneReversement.aReverser;
    case 'DEJA_REVERSEE':
      return StatutLigneReversement.dejaReversee;
    case 'INTROUVABLE':
      return StatutLigneReversement.introuvable;
    default:
      return StatutLigneReversement.inconnu;
  }
}

/// Une ligne de quittance rapprochée avec une contravention en base.
class LigneReversementModel {
  final String numeroContravention;
  final String? plaque;
  final String? codeInfraction;
  final double? montantQuittance;
  final int? contraventionId;
  final double? montantSysteme;
  final StatutLigneReversement statut;
  final bool montantDivergent;

  const LigneReversementModel({
    required this.numeroContravention,
    this.plaque,
    this.codeInfraction,
    this.montantQuittance,
    this.contraventionId,
    this.montantSysteme,
    this.statut = StatutLigneReversement.inconnu,
    this.montantDivergent = false,
  });

  /// Reversable = trouvée en base et non déjà reversée.
  bool get reversable =>
      statut == StatutLigneReversement.aReverser && contraventionId != null;

  factory LigneReversementModel.fromJson(Map<String, dynamic> json) {
    return LigneReversementModel(
      numeroContravention: json['numeroContravention'] as String? ?? '',
      plaque: json['plaque'] as String?,
      codeInfraction: json['codeInfraction'] as String?,
      montantQuittance: (json['montantQuittance'] as num?)?.toDouble(),
      contraventionId: (json['contraventionId'] as num?)?.toInt(),
      montantSysteme: (json['montantSysteme'] as num?)?.toDouble(),
      statut: _statutFrom(json['statut'] as String?),
      montantDivergent: json['montantDivergent'] as bool? ?? false,
    );
  }
}
