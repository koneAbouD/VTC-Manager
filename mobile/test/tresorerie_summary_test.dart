import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/features/tresorerie/domain/entities/compte_tresorerie.dart';

void main() {
  group('TresorerieSummary', () {
    test('lit dépôts et disponible réel renvoyés par le serveur', () {
      final s = TresorerieSummary.fromJson({
        'comptes': [],
        'totalTresorerie': 1250000,
        'aReverserEtat': 35000,
        'depotsCotisations': 420000,
        'disponibleReel': 795000,
      });

      expect(s.depotsCotisations, 420000);
      expect(s.disponibleReel, 795000);
      expect(s.couvertureInsuffisante, isFalse);
    });

    test('un serveur antérieur : le disponible se recalcule, même formule', () {
      final s = TresorerieSummary.fromJson({
        'comptes': [],
        'totalTresorerie': 100000,
        'aReverserEtat': 20000,
      });

      expect(s.depotsCotisations, 0);
      expect(s.disponibleReel, 80000);
    });

    test('des dépôts supérieurs au total déclenchent l\'alerte de couverture', () {
      final s = TresorerieSummary.fromJson({
        'comptes': [],
        'totalTresorerie': 300000,
        'aReverserEtat': 0,
        'depotsCotisations': 420000,
        'disponibleReel': -120000,
      });

      expect(s.couvertureInsuffisante, isTrue);
    });
  });
}
