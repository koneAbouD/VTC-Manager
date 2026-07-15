import '../../domain/entities/operation_financiere.dart';

class OperationFinanciereModel extends OperationFinanciere {
  const OperationFinanciereModel({
    required super.id,
    super.libelle,
    super.montant,
    super.isRevenu,
    super.date,
    super.vehicule,
    super.chauffeur,
    super.statut,
  });

  factory OperationFinanciereModel.fromJson(Map<String, dynamic> j) {
    final cat = j['categorie'] as Map?;
    final veh = j['vehicule'] as Map?;
    final chauf = j['chauffeur'] as Map?;
    final chaufNom = chauf == null
        ? null
        : '${chauf['prenom'] ?? ''} ${chauf['nom'] ?? ''}'.trim();
    return OperationFinanciereModel(
      id: j['id'] as int,
      libelle: (cat?['libelle'] ?? cat?['code']) as String?,
      montant: (j['montant'] as num?)?.toDouble(),
      isRevenu: (j['typeOperation'] as String?)?.toUpperCase() == 'REVENU',
      date: j['dateOperation'] as String?,
      vehicule: veh?['immatriculation'] as String?,
      chauffeur: (chaufNom == null || chaufNom.isEmpty) ? null : chaufNom,
      statut: j['statut'] as String?,
    );
  }
}
