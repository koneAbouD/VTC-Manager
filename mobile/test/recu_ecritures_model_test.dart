import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/features/recu/data/models/recu_ecritures_model.dart';

void main() {
  group('recuEcrituresFromJson', () {
    test('un versement : journées nommées, véhicule unique, mode unique', () {
      final r = recuEcrituresFromJson({
        'chauffeurNom': 'Jean Kouassi',
        'chauffeurTelephone': '0700000000',
        'vehicules': ['1234 AB 01'],
        'modesPaiement': ['ESPECES'],
        'lignes': [
          {
            'libelle': 'Recette',
            'nature': 'RECETTE',
            'journee': '2026-09-11',
            'payeLe': '2026-09-12',
            'montant': 15000,
            'referenceEcriture': 'ENC-1',
          },
          {
            'libelle': 'Cotisation carburant',
            'nature': 'COTISATION',
            'journee': '2026-09-11',
            'payeLe': '2026-09-12',
            'montant': 2000,
            'referenceEcriture': 'ENC-2',
          },
        ],
        'total': 17000,
        'resteDu': 5000,
      });

      expect(r.telephone, '0700000000');
      expect(r.recu.chauffeur, 'Jean Kouassi');
      expect(r.recu.vehicule, '1234 AB 01');
      expect(r.recu.modePaiement, 'Espèces');
      expect(r.recu.lignes.map((l) => l.libelle),
          ['Recette du 11/09/2026', 'Cotisation carburant du 11/09/2026']);
      expect(r.recu.total, 17000);
      expect(r.recu.resteDu, 5000);
      expect(r.recu.date, DateTime(2026, 9, 12));
      // Plusieurs écritures : pas de référence unique à citer.
      expect(r.recu.reference, isNull);
    });

    test('véhicules ou modes mêlés : le reçu se tait plutôt que de choisir', () {
      final r = recuEcrituresFromJson({
        'vehicules': ['A', 'B'],
        'modesPaiement': ['ESPECES', 'MOBILE_MONEY'],
        'lignes': [
          {
            'libelle': 'Recette',
            'journee': '2026-09-10',
            'payeLe': '2026-09-12',
            'montant': 1000,
            'referenceEcriture': 'ENC-9',
            'referencePaiement': 'MM-42',
          },
        ],
        'resteDu': null,
      });

      expect(r.recu.vehicule, isNull);
      expect(r.recu.modePaiement, isNull);
      expect(r.recu.resteDu, isNull);
      // Une seule écriture : la référence Mobile Money prime.
      expect(r.recu.reference, 'MM-42');
    });
  });
}
