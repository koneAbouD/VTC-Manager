import '../../domain/entities/ligne_penalite.dart';
import 'encaissement_penalite_model.dart';

class LignePenaliteModel extends LignePenalite {
  const LignePenaliteModel({
    super.id,
    required super.vehiculeId,
    super.vehiculeImmatriculation,
    required super.chauffeurId,
    super.chauffeurNomComplet,
    super.penaliteTemplateId,
    required super.typePenalite,
    required super.typeSanction,
    required super.montant,
    required super.montantEncaisse,
    super.montantRestant,
    super.dureeSanctionSecondes,
    super.dureeImmobilisationMinutes,
    super.dateDebutImmobilisation,
    super.dateFinImmobilisation,
    required super.dateGeneration,
    super.dateFaute,
    super.ligneRecetteId,
    required super.statut,
    super.commentaire,
    super.encaissements,
  });

  factory LignePenaliteModel.fromJson(Map<String, dynamic> j) =>
      LignePenaliteModel(
        id: j['id'] as int?,
        vehiculeId: j['vehiculeId'] as int? ?? 0,
        vehiculeImmatriculation: j['vehiculeImmatriculation'] as String?,
        chauffeurId: j['chauffeurId'] as int? ?? 0,
        chauffeurNomComplet: j['chauffeurNomComplet'] as String?,
        penaliteTemplateId: j['penaliteTemplateId'] as int?,
        typePenalite: j['typePenalite'] as String? ?? '',
        typeSanction: TypeSanctionLigne.fromString(j['typeSanction'] as String?),
        montant: (j['montant'] as num?)?.toDouble() ?? 0,
        montantEncaisse: (j['montantEncaisse'] as num?)?.toDouble() ?? 0,
        montantRestant: (j['montantRestant'] as num?)?.toDouble(),
        dureeSanctionSecondes: j['dureeSanctionSecondes'] as int?,
        dureeImmobilisationMinutes: j['dureeImmobilisationMinutes'] as int?,
        dateDebutImmobilisation: j['dateDebutImmobilisation'] != null
            ? DateTime.parse(j['dateDebutImmobilisation'] as String)
            : null,
        dateFinImmobilisation: j['dateFinImmobilisation'] != null
            ? DateTime.parse(j['dateFinImmobilisation'] as String)
            : null,
        dateGeneration: j['dateGeneration'] != null
            ? DateTime.parse(j['dateGeneration'] as String)
            : DateTime.now(),
        dateFaute: j['dateFaute'] != null
            ? DateTime.parse(j['dateFaute'] as String)
            : null,
        ligneRecetteId: j['ligneRecetteId'] as int?,
        statut: StatutLignePenalite.fromString(j['statut'] as String?),
        commentaire: j['commentaire'] as String?,
        encaissements: (j['encaissements'] as List<dynamic>?)
                ?.map((e) => EncaissementPenaliteModel.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
