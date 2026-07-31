import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/partenaire/domain/entities/dette_groupee.dart';
import 'package:vtc_manager/features/partenaire/domain/entities/facture_partenaire.dart';

FacturePartenaire _dette({
  required int id,
  int? maintenanceId,
  int? partenaireId,
  String? partenaireNom,
  String? categorieLibelle,
  String? immatriculation,
  double restantDu = 10000,
  DateTime? echeance,
  bool enRetard = false,
  List<String> postes = const [],
}) =>
    FacturePartenaire(
      id: id,
      maintenanceId: maintenanceId,
      partenaireId: partenaireId,
      partenaireNom: partenaireNom,
      categorieLibelle: categorieLibelle,
      vehiculeImmatriculation: immatriculation,
      dateFacture: DateTime(2026, 7, 12),
      dateEcheance: echeance ?? DateTime(2026, 8, 12),
      montant: restantDu,
      restantDu: restantDu,
      enRetard: enRetard,
      lignes: [
        for (final p in postes) LigneDette(libelle: p, montant: 1000),
      ],
    );

void main() {
  group('regroupement par maintenance', () {
    test('rassemble les partenaires intervenus sur une même intervention', () {
      final groupes = GroupeDette.grouper([
        _dette(
            id: 1,
            maintenanceId: 7,
            partenaireNom: 'Garage Nord',
            categorieLibelle: 'Réparation',
            immatriculation: 'AA-123-BB',
            restantDu: 30000,
            postes: ['Plaquettes']),
        _dette(
            id: 2,
            maintenanceId: 7,
            partenaireNom: 'Pneus Express',
            categorieLibelle: 'Réparation',
            immatriculation: 'AA-123-BB',
            restantDu: 20000,
            postes: ['Pneu avant', 'Pneu arrière']),
      ], VueDette.parMaintenance);

      expect(groupes, hasLength(1));
      expect(groupes.single.id, 7);
      expect(groupes.single.titre, 'Réparation');
      expect(groupes.single.contexte, 'AA-123-BB');
      expect(groupes.single.restantDu, 50000);
      expect(groupes.single.nbPostes, 3);
      expect(groupes.single.factures.map((f) => f.partenaireNom),
          containsAllInOrder(['Garage Nord', 'Pneus Express']));
    });

    test('rassemble à part les dettes sans intervention', () {
      final groupes = GroupeDette.grouper([
        _dette(id: 1, maintenanceId: 7, categorieLibelle: 'Réparation'),
        _dette(id: 2, partenaireNom: 'Assureur'),
        _dette(id: 3, partenaireNom: 'Bailleur'),
      ], VueDette.parMaintenance);

      expect(groupes, hasLength(2));
      final horsIntervention = groupes.firstWhere((g) => g.id == null);
      expect(horsIntervention.titre, 'Hors intervention');
      expect(horsIntervention.factures, hasLength(2));
    });
  });

  group('regroupement par partenaire', () {
    test('rassemble tout ce qu’on doit à un même partenaire', () {
      final groupes = GroupeDette.grouper([
        _dette(
            id: 1,
            partenaireId: 3,
            partenaireNom: 'Garage Nord',
            maintenanceId: 7,
            restantDu: 30000,
            postes: ['Plaquettes']),
        _dette(
            id: 2,
            partenaireId: 3,
            partenaireNom: 'Garage Nord',
            maintenanceId: 9,
            restantDu: 15000,
            postes: ['Vidange']),
        _dette(id: 3, partenaireId: 4, partenaireNom: 'Pneus Express'),
      ], VueDette.parPartenaire);

      expect(groupes, hasLength(2));
      final garage = groupes.firstWhere((g) => g.id == 3);
      expect(garage.titre, 'Garage Nord');
      expect(garage.restantDu, 45000);
      expect(garage.nbPostes, 2);
      expect(garage.factures.map((f) => f.maintenanceId), [7, 9]);
    });
  });

  group('urgence du groupe', () {
    test('retient le pire retard et l’échéance la plus proche', () {
      final groupes = GroupeDette.grouper([
        _dette(
            id: 1,
            maintenanceId: 7,
            echeance: DateTime(2026, 7, 20),
            enRetard: true),
        _dette(
            id: 2,
            maintenanceId: 7,
            echeance: DateTime(2026, 7, 28),
            enRetard: true),
      ], VueDette.parMaintenance);

      final groupe = groupes.single;
      expect(groupe.enRetard, isTrue);
      expect(groupe.prochaineEcheance, DateTime(2026, 7, 20));
      // Le 31/07, la plus ancienne échéance accuse 11 jours de retard.
      expect(groupe.joursDeRetard(DateTime(2026, 7, 31)), 11);
    });

    test('un groupe sans retard porte sa prochaine échéance', () {
      final groupe = GroupeDette.grouper([
        _dette(id: 1, maintenanceId: 7, echeance: DateTime(2026, 9, 1)),
      ], VueDette.parMaintenance)
          .single;

      expect(groupe.enRetard, isFalse);
      expect(groupe.joursDeRetard(DateTime(2026, 7, 31)), 0);
    });
  });

  test('l’ordre d’urgence de l’échéancier est conservé', () {
    final groupes = GroupeDette.grouper([
      _dette(id: 1, maintenanceId: 9, enRetard: true),
      _dette(id: 2, maintenanceId: 7),
      _dette(id: 3, maintenanceId: 9, enRetard: true),
    ], VueDette.parMaintenance);

    expect(groupes.map((g) => g.id), [9, 7]);
  });
}
