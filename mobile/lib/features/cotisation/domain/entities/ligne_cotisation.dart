import 'encaissement_cotisation.dart';

enum StatutLigneCotisation {
  enAttente,
  partiellementEncaisse,
  encaisse,
  annulee,

  /// Dépôt rendu au chauffeur par un arrêté de compte : hors fonds restituable,
  /// et plus encaissable. Son absence de cette liste faisait tomber les lignes
  /// restituées sur « En attente » — elles gonflaient ce compteur et se voyaient
  /// proposer un bouton « Encaisser » que le serveur refuse.
  restituee;

  static StatutLigneCotisation fromJson(String v) => switch (v) {
        'EN_ATTENTE'             => enAttente,
        'PARTIELLEMENT_ENCAISSE' => partiellementEncaisse,
        'ENCAISSE'               => encaisse,
        'ANNULEE'                => annulee,
        'RESTITUEE'              => restituee,
        _                        => enAttente,
      };

  String get json => switch (this) {
        enAttente             => 'EN_ATTENTE',
        partiellementEncaisse => 'PARTIELLEMENT_ENCAISSE',
        encaisse              => 'ENCAISSE',
        annulee               => 'ANNULEE',
        restituee             => 'RESTITUEE',
      };

  String get label => switch (this) {
        enAttente             => 'En attente',
        partiellementEncaisse => 'Partiellement encaissé',
        encaisse              => 'Encaissé',
        annulee               => 'Annulée',
        restituee             => 'Restituée',
      };
}

class LigneCotisation {
  final int? id;
  final int vehiculeId;
  final String? vehiculeImmatriculation;
  final int chauffeurId;
  final String? chauffeurNom;
  final DateTime dateCotisation;
  final String nomCotisation;
  final double montantDu;
  final double montantEncaisse;
  final double? montantRestant;
  final StatutLigneCotisation statut;
  final String? motifAnnulation;

  /// Faux si un arrêté — période comptable close, caisse comptée — interdit
  /// désormais la restauration. Le bouton « Restaurer » est alors masqué :
  /// le serveur refuserait.
  final bool restaurable;
  final List<EncaissementCotisation> encaissements;

  const LigneCotisation({
    this.id,
    required this.vehiculeId,
    this.vehiculeImmatriculation,
    required this.chauffeurId,
    this.chauffeurNom,
    required this.dateCotisation,
    required this.nomCotisation,
    required this.montantDu,
    required this.montantEncaisse,
    this.montantRestant,
    required this.statut,
    this.motifAnnulation,
    this.restaurable = false,
    this.encaissements = const [],
  });

  bool get estActive =>
      statut == StatutLigneCotisation.enAttente ||
      statut == StatutLigneCotisation.partiellementEncaisse;
}
