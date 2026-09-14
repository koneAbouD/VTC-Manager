/// La pièce de caisse : un billet remis au guichet, et les écritures qu'il a
/// produites — la recette du jour au résultat, sa cotisation en compte de tiers.
///
/// Ce n'est pas une écriture de plus. Le journal en garde une par créance ; le
/// versement ne fait que les lire ensemble, pour les montrer et les quittancer
/// d'un seul tenant.
library;

import '../../../operation_financiere/domain/enums/mode_paiement.dart';

/// La créance qu'une écriture du versement solde.
enum NatureImputation {
  recette,
  cotisation;

  static NatureImputation? fromJson(String? value) => switch (value) {
        'RECETTE' => recette,
        'COTISATION' => cotisation,
        _ => null,
      };
}

/// Une écriture du versement, lue du côté de la créance qu'elle solde.
class ImputationVersement {
  final int operationId;
  final String? reference;
  final NatureImputation? nature;

  /// Ce qui est nommé au chauffeur : « Recette », ou le nom de la cotisation.
  final String? libelle;
  final int? ligneId;

  /// La journée réglée — pas le jour du versement.
  final DateTime? dateReference;
  final double montant;

  /// Écriture extournée : le billet a été remis, mais elle ne compte plus.
  final bool annulee;

  /// Nul pour une recette au montant réel, qui n'a pas de dû d'avance.
  final double? resteDu;

  const ImputationVersement({
    required this.operationId,
    this.reference,
    this.nature,
    this.libelle,
    this.ligneId,
    this.dateReference,
    required this.montant,
    this.annulee = false,
    this.resteDu,
  });

  factory ImputationVersement.fromJson(Map<String, dynamic> json) =>
      ImputationVersement(
        operationId: (json['operationId'] as num).toInt(),
        reference: json['reference'] as String?,
        nature: NatureImputation.fromJson(json['nature'] as String?),
        libelle: json['libelle'] as String?,
        ligneId: (json['ligneId'] as num?)?.toInt(),
        dateReference: json['dateReference'] != null
            ? DateTime.tryParse(json['dateReference'] as String)
            : null,
        montant: (json['montant'] as num? ?? 0).toDouble(),
        annulee: json['annulee'] as bool? ?? false,
        resteDu: (json['resteDu'] as num?)?.toDouble(),
      );
}

class Versement {
  final String versementId;
  final DateTime dateEncaissement;
  final ModePaiement? modePaiement;
  final int? chauffeurId;
  final String? chauffeurNom;
  final String? chauffeurTelephone;
  final int? vehiculeId;
  final String? vehiculeImmatriculation;

  /// Imputations extournées exclues — calculé par le serveur.
  final double total;
  final List<ImputationVersement> imputations;

  const Versement({
    required this.versementId,
    required this.dateEncaissement,
    this.modePaiement,
    this.chauffeurId,
    this.chauffeurNom,
    this.chauffeurTelephone,
    this.vehiculeId,
    this.vehiculeImmatriculation,
    required this.total,
    required this.imputations,
  });

  /// Ce que le billet atteste encore.
  List<ImputationVersement> get actives =>
      imputations.where((i) => !i.annulee).toList();

  /// Ce que le chauffeur doit encore sur les créances du versement. Nul dès
  /// qu'une seule l'ignore : une somme partielle se lirait comme un solde.
  double? get resteDu {
    final restes = actives.map((i) => i.resteDu).toList();
    if (restes.isEmpty || restes.any((r) => r == null)) return null;
    return restes.fold<double>(0, (t, r) => t + r!);
  }

  factory Versement.fromJson(Map<String, dynamic> json) {
    final mode = json['modePaiement'] as String?;
    return Versement(
      versementId: json['versementId'] as String,
      dateEncaissement: DateTime.parse(json['dateEncaissement'] as String),
      modePaiement: mode != null ? ModePaiementExt.fromString(mode) : null,
      chauffeurId: (json['chauffeurId'] as num?)?.toInt(),
      chauffeurNom: json['chauffeurNom'] as String?,
      chauffeurTelephone: json['chauffeurTelephone'] as String?,
      vehiculeId: (json['vehiculeId'] as num?)?.toInt(),
      vehiculeImmatriculation: json['vehiculeImmatriculation'] as String?,
      total: (json['total'] as num? ?? 0).toDouble(),
      imputations: ((json['imputations'] as List?) ?? const [])
          .map((e) => ImputationVersement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
