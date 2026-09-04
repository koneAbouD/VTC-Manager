import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:vtc_manager/features/etat_parc/data/models/etat_parc_summary_model.dart';
import 'package:vtc_manager/features/etat_parc/presentation/providers/etat_parc_provider.dart';
import 'package:vtc_manager/features/etat_parc/presentation/widgets/etat_parc_synthese.dart';
import 'package:vtc_manager/features/vehicule/domain/entities/statut_vehicule.dart';
import 'package:vtc_manager/features/vehicule/presentation/providers/referentiel_provider.dart';

/// Liste d'exceptions représentative : deux immobilisés de motifs différents,
/// un disponible sans chauffeur, un véhicule en service dont la maintenance est
/// planifiée et un dont la vidange est due.
final _exceptions = [
  const VehiculeExceptionModel(
      vehiculeId: 1,
      immatriculation: 'IMM-1',
      libelleVehicule: '',
      statut: 'IMMOBILISE',
      motif: 'PANNE_OU_ACCIDENT',
      joursDansStatut: 9),
  const VehiculeExceptionModel(
      vehiculeId: 2,
      immatriculation: 'IMM-2',
      libelleVehicule: '',
      statut: 'IMMOBILISE',
      motif: 'IMMOBILISATION_PENALITE',
      joursDansStatut: 4),
  const VehiculeExceptionModel(
      vehiculeId: 3,
      immatriculation: 'IMM-3',
      libelleVehicule: '',
      statut: 'DISPONIBLE',
      motif: 'SANS_CHAUFFEUR',
      joursDansStatut: 2),
  VehiculeExceptionModel(
      vehiculeId: 4,
      immatriculation: 'IMM-4',
      libelleVehicule: '',
      statut: 'EN_SERVICE',
      motif: 'MAINTENANCE_PREVUE',
      joursDansStatut: null,
      dateMaintenancePrevue: DateTime(2026, 9, 9)),
  const VehiculeExceptionModel(
      vehiculeId: 5,
      immatriculation: 'IMM-5',
      libelleVehicule: '',
      statut: 'EN_SERVICE',
      motif: 'VIDANGE_DUE',
      joursDansStatut: null,
      kmRestantVidange: 300),
];

EtatParcSummaryModel _summary(List<VehiculeExceptionModel> exceptions) =>
    EtatParcSummaryModel(
      totalVehicules: 6,
      parcActif: 6,
      enService: 2,
      disponibles: 1,
      enMaintenance: 1,
      immobilises: 2,
      horsParc: 0,
      tauxDisponibilite: 50,
      tauxUtilisation: 33.3,
      exceptions: exceptions,
      alertes: const EtatParcAlertesModel(
        documentsExpirantSous30Jours: 0,
        maintenancesDuesSous7Jours: 0,
        permisExpires: 0,
        vidangesDues: 0,
      ),
    );

Future<void> _pumpSynthese(
  WidgetTester tester,
  List<VehiculeExceptionModel> exceptions, {
  Size taille = const Size(390, 844),
  ExceptionCritere? critere,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      // Référentiel des statuts figé : pas d'appel réseau depuis un test.
      statutsVehiculeResolvedProvider
          .overrideWithValue(StatutVehicule.fallback),
      etatParcSummaryProvider.overrideWith((ref) async => _summary(exceptions)),
      if (critere != null)
        etatParcExceptionCritereProvider.overrideWith((ref) => critere),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [EtatParcSynthese()],
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR', null));

  testWidgets('sans critère, toute la liste est affichée et le bouton dit Tous',
      (tester) async {
    await _pumpSynthese(tester, _exceptions);

    expect(find.text('Tous'), findsOneWidget);
    for (final immat in ['IMM-1', 'IMM-2', 'IMM-3', 'IMM-4', 'IMM-5']) {
      expect(find.text(immat), findsOneWidget);
    }
  });

  testWidgets('le sélecteur ne propose que des motifs', (tester) async {
    await _pumpSynthese(tester, _exceptions);

    await tester.tap(find.text('Tous'));
    await tester.pumpAndSettle();

    // Ni en-tête de section, ni libellé de statut : la liste est plate.
    expect(find.text('PAR MOTIF'), findsNothing);
    expect(find.text('Immobilisé'), findsNothing);
    for (final motif in [
      'Panne ou accident',
      'Pénalité en cours',
      'Aucun chauffeur affecté',
      'Maintenance prévue',
      'Vidange prévue',
    ]) {
      expect(find.text(motif), findsOneWidget);
    }
  });

  testWidgets('filtrer sur la vidange ne garde que les véhicules à vidanger',
      (tester) async {
    await _pumpSynthese(tester, _exceptions);

    await tester.tap(find.text('Tous'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vidange prévue'));
    await tester.pumpAndSettle();

    expect(find.text('IMM-5'), findsOneWidget);
    for (final immat in ['IMM-1', 'IMM-2', 'IMM-3', 'IMM-4']) {
      expect(find.text(immat), findsNothing);
    }
    // Le bouton porte le critère posé, la ligne son échéance kilométrique.
    expect(find.text('Vidange prévue'), findsOneWidget);
    expect(find.text('Dans 300 km'), findsOneWidget);
  });

  testWidgets('filtrer par motif ne garde que les véhicules de ce motif',
      (tester) async {
    await _pumpSynthese(tester, _exceptions);

    await tester.tap(find.text('Tous'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maintenance prévue'));
    await tester.pumpAndSettle();

    expect(find.text('IMM-4'), findsOneWidget);
    for (final immat in ['IMM-1', 'IMM-2', 'IMM-3', 'IMM-5']) {
      expect(find.text(immat), findsNothing);
    }
  });

  testWidgets('un critère long ne fait pas déborder un écran étroit',
      (tester) async {
    await _pumpSynthese(
      tester,
      [
        ..._exceptions,
        const VehiculeExceptionModel(
            vehiculeId: 6,
            immatriculation: 'IMM-6',
            libelleVehicule: '',
            statut: 'IMMOBILISE',
            // Le plus long des libellés de motif.
            motif: 'IMMOBILISATION_INDISPONIBILITE',
            joursDansStatut: 1),
      ],
      taille: const Size(320, 568),
      // Le plus long des libellés, posé d'emblée sur le bouton.
      critere: const ExceptionCritere(motif: 'IMMOBILISATION_INDISPONIBILITE'),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('IMM-6'), findsOneWidget);
    expect(find.text('IMM-1'), findsNothing);
    expect(find.text('Immobilisé (indisponibilité)'), findsOneWidget);
  });

  test('changer le filtre groupe/activité repose le critère sur Tous', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(etatParcExceptionCritereProvider.notifier).state =
        const ExceptionCritere(motif: 'PANNE_OU_ACCIDENT');
    expect(container.read(etatParcExceptionCritereProvider).estActif, isTrue);

    // Le parc affiché change : le critère posé sur l'ancien n'a plus de sens.
    container.read(etatParcFiltreProvider.notifier).state =
        const EtatParcFiltre(groupeId: 3, groupeNom: 'Abidjan');

    expect(container.read(etatParcExceptionCritereProvider).estActif, isFalse);
  });

  testWidgets('un parc homogène ne propose pas de filtre', (tester) async {
    // Un seul statut et un seul motif : le sélecteur n'aurait que « Tous ».
    await _pumpSynthese(tester, [_exceptions[0]]);

    expect(find.text('Véhicules demandant une action'), findsOneWidget);
    expect(find.text('Tous'), findsNothing);
  });
}
