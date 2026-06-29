import '../../domain/entities/ligne_cotisation.dart';
import 'encaissement_cotisation_model.dart';

class LigneCotisationModel extends LigneCotisation {
  const LigneCotisationModel({
    super.id,
    required super.vehiculeId,
    super.vehiculeImmatriculation,
    required super.chauffeurId,
    required super.dateCotisation,
    required super.nomCotisation,
    required super.montantDu,
    required super.montantEncaisse,
    super.montantRestant,
    required super.statut,
    super.encaissements,
  });

  factory LigneCotisationModel.fromJson(Map<String, dynamic> json) {
    final enc = (json['encaissements'] as List<dynamic>?)
            ?.map((e) => EncaissementCotisationModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return LigneCotisationModel(
      id: json['id'] as int?,
      vehiculeId: json['vehiculeId'] as int,
      vehiculeImmatriculation: json['vehiculeImmatriculation'] as String?,
      chauffeurId: json['chauffeurId'] as int,
      dateCotisation: DateTime.parse(json['dateCotisation'] as String),
      nomCotisation: json['nomCotisation'] as String,
      montantDu: (json['montantDu'] as num).toDouble(),
      montantEncaisse: (json['montantEncaisse'] as num?)?.toDouble() ?? 0,
      montantRestant: (json['montantRestant'] as num?)?.toDouble(),
      statut: StatutLigneCotisation.fromJson(json['statut'] as String),
      encaissements: enc,
    );
  }
}
