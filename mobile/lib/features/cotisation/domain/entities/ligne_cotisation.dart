import 'encaissement_cotisation.dart';

enum StatutLigneCotisation {
  enAttente,
  partiellementEncaisse,
  encaisse,
  annulee;

  static StatutLigneCotisation fromJson(String v) => switch (v) {
        'EN_ATTENTE'             => enAttente,
        'PARTIELLEMENT_ENCAISSE' => partiellementEncaisse,
        'ENCAISSE'               => encaisse,
        'ANNULEE'                => annulee,
        _                        => enAttente,
      };

  String get label => switch (this) {
        enAttente             => 'En attente',
        partiellementEncaisse => 'Partiellement encaissé',
        encaisse              => 'Encaissé',
        annulee               => 'Annulée',
      };
}

class LigneCotisation {
  final int? id;
  final int vehiculeId;
  final String? vehiculeImmatriculation;
  final int chauffeurId;
  final DateTime dateCotisation;
  final String nomCotisation;
  final double montantDu;
  final double montantEncaisse;
  final double? montantRestant;
  final StatutLigneCotisation statut;
  final List<EncaissementCotisation> encaissements;

  const LigneCotisation({
    this.id,
    required this.vehiculeId,
    this.vehiculeImmatriculation,
    required this.chauffeurId,
    required this.dateCotisation,
    required this.nomCotisation,
    required this.montantDu,
    required this.montantEncaisse,
    this.montantRestant,
    required this.statut,
    this.encaissements = const [],
  });

  bool get estActive =>
      statut == StatutLigneCotisation.enAttente ||
      statut == StatutLigneCotisation.partiellementEncaisse;
}
