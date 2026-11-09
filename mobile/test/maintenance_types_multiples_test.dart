import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/maintenance/data/models/maintenance_model.dart';
import 'package:vtc_manager/features/operation_financiere/presentation/providers/catalogue_element_maintenance_provider.dart';

void main() {
  group('maintenance de plusieurs types', () {
    test('les types lus du serveur se libellent ensemble, principal en tête', () {
      final m = MaintenanceModel.fromJson({
        'id': 1,
        'type': 'VIDANGE',
        'datePrevue': '2026-11-09',
        'categorieType': {'id': 3, 'libelle': 'Vidange'},
        'categoriesTypes': [
          {'id': 3, 'libelle': 'Vidange'},
          {'id': 5, 'libelle': 'Freinage'},
        ],
      });

      expect(m.idsTypes, [3, 5]);
      expect(m.libelleTypes, 'Vidange · Freinage');
    });

    test('une maintenance d\'avant la multi-sélection garde son type', () {
      final m = MaintenanceModel.fromJson({
        'type': 'VIDANGE',
        'datePrevue': '2026-11-09',
        'categorieType': {'id': 3, 'libelle': 'Vidange'},
      });

      expect(m.idsTypes, [3]);
      expect(m.libelleTypes, 'Vidange');
    });

    test('tous les types partent au serveur', () {
      final json = MaintenanceModel(
        type: 'VIDANGE',
        datePrevue: DateTime(2026, 11, 9),
        categorieTypeId: 3,
        categorieTypeIds: const [3, 5],
      ).toJson();

      expect(json['categorieTypeId'], 3);
      expect(json['categorieTypeIds'], [3, 5]);
    });

    test('deux sélections égales désignent le même catalogue', () {
      expect(
        filtreCatalogueMaintenance(vehiculeId: 1, categorieTypeIds: [5, 3]),
        filtreCatalogueMaintenance(vehiculeId: 1, categorieTypeIds: [3, 5]),
      );
    });
  });
}
