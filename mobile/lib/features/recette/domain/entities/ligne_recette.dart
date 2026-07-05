import 'encaissement.dart';

enum StatutLigneRecette {
  enAttente,
  partiellementEncaisse,
  encaisse,
  annulee;

  static StatutLigneRecette fromJson(String value) => switch (value) {
        'EN_ATTENTE' => enAttente,
        'PARTIELLEMENT_ENCAISSE' => partiellementEncaisse,
        'ENCAISSE' => encaisse,
        'ANNULEE' => annulee,
        _ => enAttente,
      };

  String get label => switch (this) {
        enAttente => 'En attente',
        partiellementEncaisse => 'Partiellement encaissé',
        encaisse => 'Encaissé',
        annulee => 'Annulée',
      };
}

class LigneRecette {
  final int? id;
  final int vehiculeId;
  final String? vehiculeImmatriculation;
  final int chauffeurId;
  final String? chauffeurNom;
  final DateTime dateRecette;
  final double? montantAttendu;
  final double montantEncaisse;
  final double? montantRestant;
  final StatutLigneRecette statut;
  final String? motifAnnulation;
  final List<Encaissement> encaissements;

  const LigneRecette({
    this.id,
    required this.vehiculeId,
    this.vehiculeImmatriculation,
    required this.chauffeurId,
    this.chauffeurNom,
    required this.dateRecette,
    this.montantAttendu,
    required this.montantEncaisse,
    this.montantRestant,
    required this.statut,
    this.motifAnnulation,
    this.encaissements = const [],
  });

  bool get estActive =>
      statut == StatutLigneRecette.enAttente ||
      statut == StatutLigneRecette.partiellementEncaisse;
}
