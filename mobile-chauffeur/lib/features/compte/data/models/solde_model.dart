import '../../domain/entities/solde.dart';

class CompteCourantModel extends CompteCourant {
  const CompteCourantModel({
    super.libelle,
    super.fondsCotisation,
    super.totalCreances,
    super.net,
  });

  factory CompteCourantModel.fromJson(Map<String, dynamic> j) => CompteCourantModel(
        libelle: j['libelle'] as String?,
        fondsCotisation: (j['fondsCotisation'] as num?)?.toDouble(),
        totalCreances: (j['totalCreances'] as num?)?.toDouble(),
        net: (j['net'] as num?)?.toDouble(),
      );
}

class SoldeModel extends Solde {
  const SoldeModel({super.chauffeur, super.vehicule});

  factory SoldeModel.fromJson(Map<String, dynamic> j) => SoldeModel(
        chauffeur: j['chauffeur'] == null
            ? null
            : CompteCourantModel.fromJson((j['chauffeur'] as Map).cast()),
        vehicule: j['vehicule'] == null
            ? null
            : CompteCourantModel.fromJson((j['vehicule'] as Map).cast()),
      );
}
