import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/maintenance/data/models/maintenance_model.dart';
import 'package:vtc_manager/features/operation_financiere/data/models/detail_maintenance_model.dart';
import 'package:vtc_manager/features/operation_financiere/domain/entities/element_maintenance.dart';

/// Une ligne répartie : le garage répare, mais c'est un autre qui fournit la
/// pièce. Sans `partenaireId`, la dette partirait au mauvais créancier.
const _ligneRepartie = ElementMaintenance(
  catalogueElementId: 7,
  catalogueElementLibelle: 'Pneu avant',
  quantite: 4,
  montant: 100000,
  partenaireId: 42,
  partenaireNom: 'Pneus Express',
);

/// Les éléments d'une intervention partent au serveur par deux chemins — la
/// maintenance et l'opération financière. Ils doivent dire la même chose : un
/// champ oublié d'un côté se perd en silence, sans erreur ni avertissement.
///
/// C'est arrivé : `DetailMaintenanceModel` omettait `partenaireId`, et toute
/// répartition saisie depuis une opération retombait sur le partenaire de
/// l'intervention.
void main() {
  Map<String, dynamic> parCheminOperation() {
    final json =
        DetailMaintenanceModel(elements: const [_ligneRepartie]).toJson();
    return (json['elements'] as List).single as Map<String, dynamic>;
  }

  Map<String, dynamic> parCheminMaintenance() {
    final json = MaintenanceModel(
      type: 'Réparation',
      datePrevue: DateTime(2026, 7, 31),
      detailMaintenance: const DetailMaintenanceModel(
        elements: [_ligneRepartie],
      ),
    ).toJson();
    final detail = json['detailMaintenance'] as Map<String, dynamic>;
    return (detail['elements'] as List).single as Map<String, dynamic>;
  }

  test('le chemin opération transmet le prestataire de la ligne', () {
    expect(parCheminOperation(), containsPair('partenaireId', 42));
  });

  test('le chemin maintenance transmet le prestataire de la ligne', () {
    expect(parCheminMaintenance(), containsPair('partenaireId', 42));
  });

  test('les deux chemins sérialisent exactement les mêmes champs', () {
    expect(
      parCheminOperation().keys.toSet(),
      parCheminMaintenance().keys.toSet(),
    );
  });

  test('une ligne sans prestataire propre n’en invente pas', () {
    final json = DetailMaintenanceModel(
      elements: const [ElementMaintenance(libelle: 'Vidange', montant: 15000)],
    ).toJson();
    final element = (json['elements'] as List).single as Map<String, dynamic>;

    expect(element.containsKey('partenaireId'), isFalse);
  });
}
