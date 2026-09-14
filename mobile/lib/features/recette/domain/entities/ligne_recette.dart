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

  /// Numéro du chauffeur, tel que porte sa fiche. Sert à lui faire parvenir le
  /// reçu de son versement ; nul quand la fiche n'en porte pas.
  final String? chauffeurTelephone;
  final DateTime dateRecette;
  final double? montantAttendu;
  final double montantEncaisse;
  final double? montantRestant;
  final StatutLigneRecette statut;
  final String? motifAnnulation;

  /// Faux si un arrêté — période comptable close, caisse comptée — interdit
  /// désormais la restauration. Le bouton « Restaurer » est alors masqué :
  /// le serveur refuserait.
  final bool restaurable;

  /// Faux si la ligne ne peut plus changer de débiteur : un arrêté de compte
  /// l'a consignée, les livres du jour sont fermés, un paiement mobile money
  /// est en vol, ou elle est annulée. Le chauffeur n'est alors pas modifiable.
  final bool reaffectable;

  /// Ce qui ferme la réaffectation, en français — affiché à l'appui prolongé
  /// sur la ligne verrouillée. Nul quand elle est ouverte.
  final String? motifNonReaffectable;
  final List<Encaissement> encaissements;

  const LigneRecette({
    this.id,
    required this.vehiculeId,
    this.vehiculeImmatriculation,
    required this.chauffeurId,
    this.chauffeurNom,
    this.chauffeurTelephone,
    required this.dateRecette,
    this.montantAttendu,
    required this.montantEncaisse,
    this.montantRestant,
    required this.statut,
    this.motifAnnulation,
    this.restaurable = false,
    this.reaffectable = false,
    this.motifNonReaffectable,
    this.encaissements = const [],
  });

  bool get estActive =>
      statut == StatutLigneRecette.enAttente ||
      statut == StatutLigneRecette.partiellementEncaisse;
}
