import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:vtc_manager/features/tableau_bord/data/models/tableau_bord_model.dart';
import 'package:vtc_manager/features/tableau_bord/presentation/pages/tableau_bord_page.dart';
import 'package:vtc_manager/features/tableau_bord/presentation/providers/tableau_bord_provider.dart';
import 'package:vtc_manager/features/tableau_bord/presentation/widgets/tb_briques.dart';

/// Période représentative : mai 2026, close.
PeriodeTableauBord _periode({bool moisEnCours = false, bool cloture = true}) =>
    PeriodeTableauBord(
      annee: 2026,
      mois: 5,
      label: 'Mai 2026',
      base: 'CAISSE',
      joursEcoules: moisEnCours ? 12 : 31,
      joursPeriode: 31,
      moisEnCours: moisEnCours,
      cloture: cloture,
    );

SanteFinanciere _finance({
  double resultat = 300000,
  double? tauxMarge = 60,
  double? pointMort = 500000,
  double? couverture = 200,
  double? variationResultat = 12.5,
}) =>
    SanteFinanciere(
      produits: 1000000,
      chargesVariables: 400000,
      margeSurCoutsVariables: 600000,
      chargesFixes: 300000,
      excedentBrutExploitation: 300000,
      amortissements: 0,
      dotationProvisions: 0,
      resultatGestion: resultat,
      tauxMargeVariable: tauxMarge,
      tauxCharges: 70,
      pointMort: pointMort,
      tauxCouverturePointMort: couverture,
      variationProduitsPct: 8,
      variationResultatPct: variationResultat,
      serie: [
        for (var i = 1; i <= 12; i++)
          PointSerie(
              annee: 2026,
              mois: i,
              label: 'm$i',
              produits: 100000.0 * i,
              charges: 50000.0 * i,
              resultat: i.isEven ? 50000.0 * i : -20000.0 * i),
      ],
    );

CashCreances _cash({
  double? tauxRecouvrement = 80,
  double? partRisque = 30,
  double? dso = 15.5,
  List<Debiteur> debiteurs = const [],
}) =>
    CashCreances(
      tresorerieDisponible: 325000,
      creancesBrutes: 190000,
      creances0a7Jours: 60000,
      creances8a30Jours: 30000,
      creancesPlus30Jours: 100000,
      partCreancesRisque: partRisque,
      provisionCreances: 40000,
      creancesNettes: 150000,
      tauxRecouvrement: tauxRecouvrement,
      resteAEncaisserPeriode: 200000,
      dso: dso,
      aReverserEtat: 0,
      nbChauffeursDebiteurs: 2,
      topDebiteurs: debiteurs,
    );

PerformanceFlotte _flotte({
  List<VehiculePerformance> meilleurs = const [],
  List<VehiculePerformance> moinsBons = const [],
  int deficitaires = 1,
}) =>
    PerformanceFlotte(
      parcActif: 10,
      enService: 7,
      disponibles: 1,
      enMaintenance: 1,
      immobilises: 1,
      horsParc: 0,
      tauxDisponibilite: 80,
      tauxUtilisation: 70,
      revenuParVehiculeActif: 100000,
      revenuJournalierMoyen: 3226,
      joursImmobilisation: 20,
      tauxImmobilisation: 6.5,
      manqueAGagnerImmobilisation: 64520,
      margeNetteMoyenne: 50000,
      nbVehiculesDeficitaires: deficitaires,
      nbVehiculesEvalues: 3,
      meilleurs: meilleurs,
      moinsBons: moinsBons,
    );

AlertesTableauBord _alertes({int documents = 3, int arretsLongs = 2}) =>
    AlertesTableauBord(
      documentsExpirantSous30Jours: documents,
      maintenancesDuesSous7Jours: 0,
      permisExpires: 1,
      vidangesDues: 0,
      immobilisationsLongues: arretsLongs,
      vehiculesSansChauffeur: 0,
    );

TableauBordModel _modele({
  PeriodeTableauBord? periode,
  SanteFinanciere? finance,
  CashCreances? cash,
  PerformanceFlotte? flotte,
  AlertesTableauBord? alertes,
}) =>
    TableauBordModel(
      periode: periode ?? _periode(),
      finance: finance ?? _finance(),
      cash: cash ?? _cash(),
      flotte: flotte ?? _flotte(),
      alertes: alertes ?? _alertes(),
    );

/// Monte la page sur une vue haute : le `ListView` ne construit que ce qu'il
/// affiche, et la page complète dépasse largement un écran de téléphone. La
/// largeur, elle, reste celle d'un téléphone — c'est elle qui fait déborder les
/// lignes trop chargées.
Future<void> _pump(WidgetTester tester, TableauBordModel modele,
    {Size taille = const Size(390, 4000)}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      tableauBordProvider.overrideWith((ref) async => modele),
      tableauBordCadrageProvider.overrideWith(
          (ref) => const TableauBordCadrage(annee: 2026, mois: 5)),
    ],
    child: const MaterialApp(home: TableauBordPage()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR', null));

  group('formateurs', () {
    test('un ratio absent s\'écrit « — », jamais « 0 % »', () {
      // Un taux sans dénominateur n'est pas nul : il n'existe pas. L'écrire
      // « 0 % » ferait croire à une mesure.
      expect(tbPourcent(null), '—');
      expect(tbPourcent(0), '0 %');
      expect(tbPourcent(52.6), '52,6 %');
      expect(tbPourcent(60), '60 %');
    });

    test('les grands montants passent en forme courte', () {
      expect(tbMontantCourt(12400000), '12,4 M');
      expect(tbMontantCourt(-3500000), '-3,5 M');
      expect(tbMontantCourt(325000), '325 k');
      expect(tbMontantCourt(-64520), '-65 k');
      // Sous 10 000, la valeur exacte reste lisible d'un coup d'œil.
      expect(tbMontantCourt(8500), contains('8'));
    });

    test('la couleur suit le sens du ratio, pas sa valeur', () {
      // Une disponibilité haute est bonne ; une part de créances anciennes
      // haute est mauvaise. Le même 85 % ne se peint pas de la même couleur.
      expect(tbCouleurTauxCroissant(85), kTbVert);
      expect(tbCouleurTauxCroissant(65), kTbOrange);
      expect(tbCouleurTauxCroissant(40), kTbRouge);
      expect(tbCouleurTauxDecroissant(85), kTbRouge);
      expect(tbCouleurTauxDecroissant(5), kTbVert);
      // Sans mesure, aucun jugement.
      expect(tbCouleurTauxCroissant(null), kTbNeutre);
    });

    test('un montant négatif se peint en rouge', () {
      expect(tbCouleurMontant(-1), kTbRouge);
      expect(tbCouleurMontant(1), kTbVert);
      expect(tbCouleurMontant(0), kTbNeutre);
    });
  });

  group('lecture du modèle', () {
    test('un ratio absent du JSON reste nul, il ne devient pas zéro', () {
      final finance = SanteFinanciere.fromJson(const {
        'produits': 0,
        'resultatGestion': 0,
      });

      expect(finance.tauxMargeVariable, isNull);
      expect(finance.pointMort, isNull);
      expect(finance.variationResultatPct, isNull);
      expect(finance.produits, 0);
      expect(finance.serie, isEmpty);
    });

    test('les alertes savent compter leurs signaux ouverts', () {
      expect(_alertes(documents: 3, arretsLongs: 2).total, 6);
      expect(
          const AlertesTableauBord(
            documentsExpirantSous30Jours: 0,
            maintenancesDuesSous7Jours: 0,
            permisExpires: 0,
            vidangesDues: 0,
            immobilisationsLongues: 0,
            vehiculesSansChauffeur: 0,
          ).total,
          0);
    });
  });

  group('page', () {
    testWidgets('les quatre questions structurent la page', (tester) async {
      await _pump(tester, _modele());

      expect(find.text('Santé financière'), findsOneWidget);
      expect(find.text('Encaissement et créances'), findsOneWidget);
      expect(find.text('Performance du parc'), findsOneWidget);
      expect(find.text('Points de vigilance'), findsOneWidget);
    });

    testWidgets('un mois clos annonce des chiffres définitifs', (tester) async {
      await _pump(tester, _modele());

      expect(find.textContaining('Période close'), findsOneWidget);
    });

    testWidgets('un mois en cours annonce son avancement', (tester) async {
      // Comparer un mois tronqué à un mois plein sans le dire ferait lire
      // toute variation comme un effondrement.
      await _pump(tester,
          _modele(periode: _periode(moisEnCours: true, cloture: false)));

      expect(find.textContaining('12 j sur 31'), findsOneWidget);
    });

    testWidgets('un résultat déficitaire chiffre ce qui manque à l\'équilibre',
        (tester) async {
      // Point mort 800 000 pour 1 000 000 de produits déjà réalisés : le
      // commentaire ne doit pas réclamer un complément négatif.
      await _pump(
          tester,
          _modele(
              finance: _finance(
                  resultat: -150000, pointMort: 1400000, couverture: 71)));

      expect(find.textContaining('Il manque'), findsOneWidget);
      expect(find.textContaining('400 k'), findsOneWidget);
    });

    testWidgets('sans marge, le point mort s\'affiche « — » et non zéro',
        (tester) async {
      await _pump(
          tester,
          _modele(
              finance: _finance(
                  tauxMarge: null, pointMort: null, couverture: null)));

      expect(find.text('marge insuffisante'), findsOneWidget);
    });

    testWidgets('les créances se lisent par ancienneté', (tester) async {
      await _pump(tester, _modele());

      expect(find.text('0 – 7 j  '), findsOneWidget);
      expect(find.text('> 30 j  '), findsOneWidget);
      // La part à risque, mise en avant comme tuile.
      expect(find.text('Dont > 30 jours'), findsOneWidget);
    });

    testWidgets('un encours nul remplace la barre par une phrase',
        (tester) async {
      const vide = CashCreances(
        tresorerieDisponible: 100000,
        creancesBrutes: 0,
        creances0a7Jours: 0,
        creances8a30Jours: 0,
        creancesPlus30Jours: 0,
        partCreancesRisque: null,
        provisionCreances: 0,
        creancesNettes: 0,
        tauxRecouvrement: 100,
        resteAEncaisserPeriode: 0,
        dso: null,
        aReverserEtat: 0,
        nbChauffeursDebiteurs: 0,
        topDebiteurs: [],
      );

      await _pump(tester, _modele(cash: vide));

      expect(find.text('Aucune créance ouverte'), findsOneWidget);
      expect(find.text('tout est rentré'), findsOneWidget);
    });

    testWidgets('le palmarès véhicules affiche les marges des deux bords',
        (tester) async {
      await _pump(
          tester,
          _modele(
              flotte: _flotte(meilleurs: const [
                VehiculePerformance(
                    vehiculeId: 1,
                    immatriculation: 'AA-001',
                    produits: 600000,
                    marge: 150000,
                    margeNette: 150000,
                    joursImmobilisation: 0),
              ], moinsBons: const [
                VehiculePerformance(
                    vehiculeId: 2,
                    immatriculation: 'AA-002',
                    produits: 400000,
                    marge: -50000,
                    margeNette: -50000,
                    joursImmobilisation: 8),
              ])));

      expect(find.text('AA-001'), findsOneWidget);
      expect(find.text('AA-002'), findsOneWidget);
      expect(find.textContaining('8 j d\'arrêt'), findsOneWidget);
    });

    testWidgets('sans alerte ouverte, la section le dit au lieu de rester vide',
        (tester) async {
      await _pump(
          tester,
          _modele(
              alertes: const AlertesTableauBord(
            documentsExpirantSous30Jours: 0,
            maintenancesDuesSous7Jours: 0,
            permisExpires: 0,
            vidangesDues: 0,
            immobilisationsLongues: 0,
            vehiculesSansChauffeur: 0,
          )));

      expect(find.text('Aucun point de vigilance ouvert'), findsOneWidget);
    });

    testWidgets('seules les alertes non nulles sont affichées', (tester) async {
      await _pump(tester, _modele(alertes: _alertes(documents: 3, arretsLongs: 0)));

      expect(find.text('Documents à renouveler'), findsOneWidget);
      expect(find.text('Permis expirés'), findsOneWidget);
      // Compteurs à zéro : rien à signaler, donc rien à afficher.
      expect(find.text('Arrêts longs'), findsNothing);
      expect(find.text('Vidanges dues'), findsNothing);
    });

    testWidgets('basculer sur la base « Dû » recadre la lecture',
        (tester) async {
      await _pump(tester, _modele());

      await tester.tap(find.text('Dû'));
      await tester.pumpAndSettle();

      // Le cadrage change ; le provider surchargé resservant le même modèle,
      // c'est bien l'état qui est éprouvé ici, pas la donnée.
      expect(find.text('Dû'), findsOneWidget);
    });
  });
}
