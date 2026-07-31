import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/operation_financiere/data/models/element_maintenance_model.dart';
import 'package:vtc_manager/features/operation_financiere/domain/entities/element_maintenance.dart';

void main() {
  group('prix unitaire', () {
    test('se retrouve en divisant le total par la quantité', () {
      const el = ElementMaintenance(
          libelle: 'Pneu avant', quantite: 4, montant: 100000);

      expect(el.prixUnitaire, 25000);
    });

    test('vaut le total quand la ligne n’a qu’un exemplaire', () {
      const el = ElementMaintenance(libelle: 'Vidange', montant: 15000);

      expect(el.quantite, 1);
      expect(el.prixUnitaire, 15000);
    });
  });

  group('libellé de liste', () {
    test('porte le nombre à partir de deux exemplaires', () {
      const el =
          ElementMaintenance(libelle: 'Plaquette', quantite: 2, montant: 30000);

      expect(el.libelleAvecQuantite, 'Plaquette × 2');
    });

    test('reste nu à l’unité — « × 1 » n’apprendrait rien', () {
      const el = ElementMaintenance(libelle: 'Vidange', montant: 15000);

      expect(el.libelleAvecQuantite, 'Vidange');
    });
  });

  group('sérialisation', () {
    test('une ligne d’avant la quantité se relit comme un exemplaire', () {
      final el = ElementMaintenanceModel.fromJson({
        'id': 1,
        'libelle': 'Ancienne ligne',
        'montant': 12000,
      });

      expect(el.quantite, 1);
      expect(el.prixUnitaire, 12000);
    });

    test('la quantité fait l’aller-retour, le montant reste le total', () {
      final el = ElementMaintenanceModel.fromJson({
        'id': 1,
        'libelle': 'Pneu',
        'quantite': 4,
        'montant': 100000,
      });

      expect(el.quantite, 4);
      expect(el.montant, 100000);
      expect(
          ElementMaintenanceModel(
                  libelle: el.libelle,
                  quantite: el.quantite,
                  montant: el.montant)
              .toJson(),
          containsPair('quantite', 4));
      expect(
          ElementMaintenanceModel(
                  libelle: el.libelle,
                  quantite: el.quantite,
                  montant: el.montant)
              .toJson(),
          containsPair('montant', 100000));
    });
  });
}
