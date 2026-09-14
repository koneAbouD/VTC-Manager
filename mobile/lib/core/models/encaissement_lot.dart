/// Encaissement de masse : un versement du chauffeur solde plusieurs journées
/// d'un coup. Le mode, la date et le commentaire sont communs au lot ; le
/// montant, lui, est propre à chaque ligne — un chauffeur solde rarement toutes
/// ses créances au franc près.
library;

/// Ce que le guichet impute à une ligne du lot.
class MontantLigne {
  final int    ligneId;
  final double montant;

  const MontantLigne({required this.ligneId, required this.montant});

  Map<String, dynamic> toJson() => {'ligneId': ligneId, 'montant': montant};
}

/// Verdict du serveur pour une ligne. Le lot n'est pas un tout ou rien : une
/// période clôturée ou une caisse déjà comptée ne concerne que sa ligne, et le
/// [message] est rédigé côté serveur pour être affiché tel quel.
class ResultatLigneLot {
  final int     ligneId;
  final bool    succes;
  final int?    encaissementId;
  final String? message;

  /// Écritures produites, quand l'envoi les rend : ce que le reçu PDF atteste.
  final List<int> operationIds;

  const ResultatLigneLot({
    required this.ligneId,
    required this.succes,
    this.encaissementId,
    this.message,
    this.operationIds = const [],
  });

  factory ResultatLigneLot.fromJson(Map<String, dynamic> json) =>
      ResultatLigneLot(
        ligneId:        json['ligneId'] as int,
        succes:         json['succes'] as bool? ?? false,
        encaissementId: json['encaissementId'] as int?,
        message:        json['message'] as String?,
      );
}

class ResultatEncaissementLot {
  final int reussis;
  final int echecs;
  final List<ResultatLigneLot> resultats;

  const ResultatEncaissementLot({
    required this.reussis,
    required this.echecs,
    required this.resultats,
  });

  factory ResultatEncaissementLot.fromJson(Map<String, dynamic> json) =>
      ResultatEncaissementLot(
        reussis: json['reussis'] as int? ?? 0,
        echecs:  json['echecs'] as int? ?? 0,
        resultats: ((json['resultats'] as List?) ?? const [])
            .map((e) => ResultatLigneLot.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Les lignes refusées, avec leur motif — celles qu'il reste à traiter.
  List<ResultatLigneLot> get lignesEnEchec =>
      resultats.where((r) => !r.succes).toList();
}
