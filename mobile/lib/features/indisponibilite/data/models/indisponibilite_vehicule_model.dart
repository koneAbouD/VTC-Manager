import '../../domain/entities/indisponibilite_vehicule.dart';

class IndisponibiliteVehiculeModel extends IndisponibiliteVehicule {
  const IndisponibiliteVehiculeModel({
    super.id,
    required super.vehiculeId,
    super.vehiculeLibelle,
    required super.dateDebut,
    super.dateFin,
    super.motif,
    super.commentaire,
    super.statut,
  });

  static String? _libelleFrom(Map<String, dynamic>? v) {
    if (v == null) return null;
    final immat = (v['immatriculation'] as String?)?.trim() ?? '';
    final marque = _nom(v['marque']);
    final modele = _nom(v['modele']);
    final modele2 = '$marque $modele'.trim();
    if (immat.isEmpty && modele2.isEmpty) return null;
    if (modele2.isEmpty) return immat;
    if (immat.isEmpty) return modele2;
    return '$immat — $modele2';
  }

  static String _nom(dynamic o) {
    if (o is Map<String, dynamic>) return (o['nom'] as String?)?.trim() ?? '';
    return '';
  }

  factory IndisponibiliteVehiculeModel.fromJson(Map<String, dynamic> json) {
    final vehicule = json['vehicule'] as Map<String, dynamic>?;
    return IndisponibiliteVehiculeModel(
      id: json['id'] as int?,
      vehiculeId: vehicule?['id'] as int? ?? 0,
      vehiculeLibelle: _libelleFrom(vehicule),
      dateDebut: DateTime.parse(json['dateDebut'] as String),
      dateFin: json['dateFin'] != null
          ? DateTime.parse(json['dateFin'] as String)
          : null,
      motif: json['motif'] as String?,
      commentaire: json['commentaire'] as String?,
      statut: json['statut'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'vehiculeId': vehiculeId,
        'dateDebut': dateDebut.toIso8601String().substring(0, 10),
        if (dateFin != null)
          'dateFin': dateFin!.toIso8601String().substring(0, 10),
        if (motif != null) 'motif': motif,
        if (commentaire != null) 'commentaire': commentaire,
      };
}
