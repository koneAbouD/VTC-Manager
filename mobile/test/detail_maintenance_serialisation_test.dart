import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/operation_financiere/data/models/detail_maintenance_model.dart';
import 'package:vtc_manager/features/operation_financiere/domain/entities/element_maintenance.dart';

void main() {
  group('sérialisation du détail de maintenance', () {
    test('le prestataire de la ligne part au serveur', () {
      const detail = DetailMaintenanceModel(elements: [
        ElementMaintenance(
            libelle: 'Pneu avant', quantite: 4, montant: 100000,
            partenaireId: 7),
        ElementMaintenance(
            catalogueElementId: 3, montant: 15000, partenaireId: 9),
      ]);

      final elements = detail.toJson()['elements'] as List<dynamic>;

      expect(elements[0], containsPair('partenaireId', 7));
      expect(elements[1], containsPair('partenaireId', 9));
    });

    test('une ligne sans prestataire n’en invente pas — c’est celui de '
        'l’intervention qui prendra le relais côté serveur', () {
      const detail = DetailMaintenanceModel(elements: [
        ElementMaintenance(libelle: 'Vidange', montant: 15000),
      ]);

      final elements = detail.toJson()['elements'] as List<dynamic>;

      expect(elements.single, isNot(contains('partenaireId')));
    });

    test('quantité et total accompagnent chaque ligne', () {
      const detail = DetailMaintenanceModel(elements: [
        ElementMaintenance(libelle: 'Plaquette', quantite: 2, montant: 30000),
      ]);

      final ligne = (detail.toJson()['elements'] as List<dynamic>).single;

      expect(ligne, containsPair('quantite', 2));
      expect(ligne, containsPair('montant', 30000));
      expect(ligne, containsPair('libelle', 'Plaquette'));
    });
  });
}
