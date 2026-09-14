/// Ce que le guichet envoie pour encaisser un versement, et ce qui en revient.
///
/// Un versement solde la recette du jour, sa cotisation, ou les deux, et il
/// est **tout ou rien** : si l'une des deux créances est refusée, l'autre ne
/// passe pas. Le client n'a plus à gérer un billet enregistré à moitié.
library;

/// Ce qu'un versement impute à une créance.
class PartVersement {
  final int ligneId;
  final double montant;

  const PartVersement({required this.ligneId, required this.montant});

  Map<String, dynamic> toJson() => {'ligneId': ligneId, 'montant': montant};
}

/// Réponse à l'encaissement d'un versement. [versementId] est nul quand une
/// seule créance était soldée : rien n'est rassemblé.
class VersementEnregistre {
  final String? versementId;

  const VersementEnregistre({this.versementId});

  factory VersementEnregistre.fromJson(Map<String, dynamic> json) =>
      VersementEnregistre(versementId: json['versementId'] as String?);
}

/// Un versement d'un lot : la journée de recette et sa cotisation du jour.
class ElementVersementLot {
  final PartVersement? recette;
  final PartVersement? cotisation;

  const ElementVersementLot({this.recette, this.cotisation});

  Map<String, dynamic> toJson() => {
        if (recette != null) 'recette': recette!.toJson(),
        if (cotisation != null) 'cotisation': cotisation!.toJson(),
      };
}

/// Verdict du serveur pour un versement du lot, motif rédigé pour l'écran.
class VerdictVersementLot {
  final int? ligneRecetteId;
  final int? ligneCotisationId;
  final bool succes;
  final String? versementId;
  final String? message;

  const VerdictVersementLot({
    this.ligneRecetteId,
    this.ligneCotisationId,
    required this.succes,
    this.versementId,
    this.message,
  });

  factory VerdictVersementLot.fromJson(Map<String, dynamic> json) =>
      VerdictVersementLot(
        ligneRecetteId: (json['ligneRecetteId'] as num?)?.toInt(),
        ligneCotisationId: (json['ligneCotisationId'] as num?)?.toInt(),
        succes: json['succes'] as bool? ?? false,
        versementId: json['versementId'] as String?,
        message: json['message'] as String?,
      );
}

class ResultatVersementLot {
  final int reussis;
  final int echecs;
  final List<VerdictVersementLot> resultats;

  const ResultatVersementLot({
    required this.reussis,
    required this.echecs,
    required this.resultats,
  });

  factory ResultatVersementLot.fromJson(Map<String, dynamic> json) =>
      ResultatVersementLot(
        reussis: json['reussis'] as int? ?? 0,
        echecs: json['echecs'] as int? ?? 0,
        resultats: ((json['resultats'] as List?) ?? const [])
            .map((e) => VerdictVersementLot.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
