import '../../domain/entities/encaissement.dart';
import '../../domain/entities/ligne_recette.dart';
import 'encaissement_model.dart';

class LigneRecetteModel extends LigneRecette {
  const LigneRecetteModel({
    super.id,
    required super.vehiculeId,
    super.vehiculeImmatriculation,
    required super.chauffeurId,
    required super.dateRecette,
    super.montantAttendu,
    required super.montantEncaisse,
    super.montantRestant,
    required super.statut,
    super.encaissements,
  });

  factory LigneRecetteModel.fromJson(Map<String, dynamic> json) {
    final encaissementsJson = json['encaissements'] as List<dynamic>?;
    final encaissements = encaissementsJson
            ?.map((e) => EncaissementModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return LigneRecetteModel(
      id: json['id'] as int?,
      vehiculeId: json['vehiculeId'] as int,
      vehiculeImmatriculation: json['vehiculeImmatriculation'] as String?,
      chauffeurId: json['chauffeurId'] as int,
      dateRecette: DateTime.parse(json['dateRecette'] as String),
      montantAttendu: (json['montantAttendu'] as num?)?.toDouble(),
      montantEncaisse: (json['montantEncaisse'] as num?)?.toDouble() ?? 0,
      montantRestant: (json['montantRestant'] as num?)?.toDouble(),
      statut: StatutLigneRecette.fromJson(json['statut'] as String),
      encaissements: encaissements,
    );
  }
}
