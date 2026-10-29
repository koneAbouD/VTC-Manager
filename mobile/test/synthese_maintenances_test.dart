import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/core/theme/app_colors.dart';
import 'package:vtc_manager/core/theme/app_palette.dart';
import 'package:vtc_manager/features/maintenance/domain/entities/synthese_maintenances.dart';
import 'package:vtc_manager/features/maintenance/presentation/widgets/maintenance_visuels.dart';

void main() {
  tearDown(() => AppColors.appliquer(AppAccent.vert, Brightness.light));

  group('SyntheseMaintenances.fromJson', () {
    test('lit les tuiles de types, les statuts et le retard du serveur', () {
      final s = SyntheseMaintenances.fromJson({
        'parType': [
          {
            'categorieTypeId': 13,
            'code': 'VIDANGE',
            'libelle': 'Vidange',
            'nombre': 14,
            'coutRealise': 280000.00,
          },
        ],
        'parStatut': [
          {'statut': 'PLANIFIEE', 'nombre': 3},
          {'statut': 'EN_COURS', 'nombre': 0},
          {'statut': 'TERMINEE', 'nombre': 11},
          {'statut': 'ANNULEE', 'nombre': 2},
        ],
        'enRetard': 1,
      });

      expect(s.parType.single.libelle, 'Vidange');
      expect(s.parType.single.coutRealise, 280000);
      expect(s.nombre('TERMINEE'), 11);
      // « Tous » additionne les statuts, retard non compris : il est déjà
      // compté parmi les planifiées.
      expect(s.total, 16);
      expect(s.enRetard, 1);
    });

    test('écarte un type sans identifiant, qui ne pourrait pas filtrer', () {
      final s = SyntheseMaintenances.fromJson({
        'parType': [
          {'categorieTypeId': null, 'code': 'X', 'libelle': 'X', 'nombre': 1},
        ],
        'parStatut': const [],
        'enRetard': 0,
      });
      expect(s.parType, isEmpty);
      expect(s.nombre('PLANIFIEE'), 0);
    });
  });

  group('Retard', () {
    final maintenant = DateTime(2026, 10, 29, 9, 41);

    test('une planifiée dont la date est passée compte ses jours de retard', () {
      expect(
          StatutMaintenanceVisuel.joursDeRetard(
              'PLANIFIEE', DateTime(2026, 10, 26),
              maintenant: maintenant),
          3);
    });

    test("une planifiée du jour n'est pas en retard", () {
      expect(
          StatutMaintenanceVisuel.joursDeRetard(
              'PLANIFIEE', DateTime(2026, 10, 29, 23),
              maintenant: maintenant),
          0);
    });

    test("une intervention close n'est jamais en retard", () {
      for (final statut in ['TERMINEE', 'ANNULEE', 'EN_COURS']) {
        expect(
            StatutMaintenanceVisuel.joursDeRetard(
                statut, DateTime(2026, 9, 1),
                maintenant: maintenant),
            0,
            reason: statut);
      }
    });
  });

  group('TypeMaintenanceVisuel', () {
    test('reconnaît un type par son code comme par son libellé accentué', () {
      final parCode = TypeMaintenanceVisuel.de(code: 'ELECTRICITE');
      final parLibelle = TypeMaintenanceVisuel.de(libelle: 'Électricité');
      expect(parLibelle.icone, parCode.icone);
      expect(parLibelle.couleur, parCode.couleur);
    });

    test('un type inconnu garde la même teinte de repli à chaque affichage', () {
      final a = TypeMaintenanceVisuel.de(code: 'CARROSSERIE_X', id: 42);
      final b = TypeMaintenanceVisuel.de(code: 'CARROSSERIE_X', id: 42);
      expect(a.couleur, b.couleur);
      expect(a.icone, Icons.construction_outlined);
    });

    test('la couleur du type suit le thème sombre', () {
      final clair = TypeMaintenanceVisuel.de(code: 'VIDANGE').couleur;
      AppColors.appliquer(AppAccent.vert, Brightness.dark);
      final sombre = TypeMaintenanceVisuel.de(code: 'VIDANGE').couleur;
      expect(sombre, isNot(clair));
    });
  });
}
