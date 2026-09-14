import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:vtc_manager/core/error/failure.dart';
import 'package:vtc_manager/features/cotisation/domain/entities/ligne_cotisation.dart';
import 'package:vtc_manager/features/cotisation/domain/entities/ligne_cotisation_filtres.dart';
import 'package:vtc_manager/features/cotisation/domain/repositories/ligne_cotisation_repository.dart';
import 'package:vtc_manager/features/cotisation/presentation/providers/ligne_cotisation_provider.dart';
import 'package:vtc_manager/features/recette/domain/entities/ligne_recette.dart';
import 'package:vtc_manager/features/recette/domain/repositories/ligne_recette_repository.dart';
import 'package:vtc_manager/features/recette/presentation/providers/ligne_recette_provider.dart';
import 'package:vtc_manager/features/vehicule/domain/entities/vehicule.dart';
import 'package:vtc_manager/features/vehicule/domain/repositories/vehicule_repository.dart';
import 'package:vtc_manager/features/vehicule/presentation/providers/vehicule_provider.dart';
import 'package:vtc_manager/screens/accueil/widgets/encaissement_rapide_dialog.dart';
import 'package:vtc_manager/features/operation_financiere/domain/enums/mode_paiement.dart';
import 'package:vtc_manager/features/versement/domain/entities/encaissement_versement.dart';
import 'package:vtc_manager/features/versement/domain/repositories/versement_repository.dart';
import 'package:vtc_manager/features/versement/presentation/providers/versement_provider.dart';

/// Un seul véhicule, une recette de 15 000 restants et une cotisation de 5 000.
class _FakeVehiculeRepo implements VehiculeRepository {
  @override
  Future<Either<Failure, List<Vehicule>>> getVehicules() async => const Right([
        Vehicule(
            id: 7,
            immatriculation: 'AA-111',
            marque: 'Toyota',
            modele: 'Corolla'),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRecetteRepo implements LigneRecetteRepository {
  @override
  Future<Either<Failure, List<LigneRecette>>> getLignes({
    int? vehiculeId,
    int? chauffeurId,
    StatutLigneRecette? statut,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async =>
      Right([
        LigneRecette(
          id: 1,
          vehiculeId: 7,
          chauffeurId: 3,
          dateRecette: DateTime(2026, 9, 1),
          montantAttendu: 15000,
          montantEncaisse: 0,
          montantRestant: 15000,
          statut: StatutLigneRecette.enAttente,
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCotisationRepo implements LigneCotisationRepository {
  /// Le 02/09 par défaut : la recette est du 01/09, les deux lignes les plus
  /// anciennes du véhicule ne sont donc pas sœurs.
  final DateTime jour;

  _FakeCotisationRepo([DateTime? jour]) : jour = jour ?? DateTime(2026, 9, 2);

  @override
  Future<Either<Failure, List<LigneCotisation>>> getLignes(
          LigneCotisationFiltres filtres) async =>
      Right([
        LigneCotisation(
          id: 2,
          vehiculeId: 7,
          chauffeurId: 3,
          dateCotisation: jour,
          nomCotisation: 'Épargne',
          montantDu: 5000,
          montantEncaisse: 0,
          montantRestant: 5000,
          statut: StatutLigneCotisation.enAttente,
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Consigne chaque versement envoyé : (ligne de recette, ligne de cotisation).
class _FakeVersementRepo implements VersementRepository {
  final List<(int?, int?)> appels = [];

  /// Refus opposé à une cotisation envoyée seule — la caisse comptée entre les
  /// deux appels, par exemple.
  String? refusCotisationSeule;

  @override
  Future<Either<Failure, VersementEnregistre>> encaisser({
    PartVersement? recette,
    PartVersement? cotisation,
    required ModePaiement mode,
    required DateTime date,
    String? reference,
    String? commentaire,
  }) async {
    appels.add((recette?.ligneId, cotisation?.ligneId));
    if (recette == null && cotisation != null && refusCotisationSeule != null) {
      return Left(ConflictFailure(refusCotisationSeule!));
    }
    return const Right(VersementEnregistre());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ouvre la feuille et sélectionne le véhicule : les deux lignes sont alors
/// chargées et le montant prérempli.
Future<void> _ouvrirEtSelectionner(
  WidgetTester tester, {
  DateTime? jourCotisation,
  _FakeVersementRepo? versements,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      vehiculeRepositoryProvider.overrideWithValue(_FakeVehiculeRepo()),
      ligneRecetteRepositoryProvider.overrideWithValue(_FakeRecetteRepo()),
      ligneCotisationRepositoryProvider
          .overrideWithValue(_FakeCotisationRepo(jourCotisation)),
      versementRepositoryProvider
          .overrideWithValue(versements ?? _FakeVersementRepo()),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showEncaissementRapideDialog(ctx),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  ));

  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();

  // Autocomplete du véhicule : saisir puis choisir l'option proposée.
  await tester.enterText(find.byType(TextFormField).first, 'AA');
  await tester.pumpAndSettle();
  await tester.tap(find.text('AA-111').last);
  await tester.pumpAndSettle();
}

Finder get _champMontant => find.byType(TextFormField).at(1);

/// Cases dans l'ordre d'affichage : recette puis cotisation.
List<Checkbox> _cases(WidgetTester tester) =>
    tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();

void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR', null));

  testWidgets('les deux lignes sont cochées et le montant prérempli au total',
      (tester) async {
    await _ouvrirEtSelectionner(tester);

    expect(find.text('Lignes actives trouvées'), findsOneWidget);
    // Le jour de chaque ligne est affiché.
    expect(find.text('mar. 01/09/2026'), findsOneWidget);
    expect(find.text('mer. 02/09/2026'), findsOneWidget);

    final cases = _cases(tester);
    expect(cases.length, 2);
    expect(cases[0].value, isTrue);
    expect(cases[1].value, isTrue);
    // 15 000 + 5 000, séparateurs de milliers compris
    expect(find.text('20 000'), findsOneWidget);
  });

  testWidgets('un montant qui ne couvre pas la recette décoche la cotisation',
      (tester) async {
    await _ouvrirEtSelectionner(tester);

    await tester.enterText(_champMontant, '15000');
    await tester.pump();

    final cases = _cases(tester);
    expect(cases[0].value, isTrue);
    expect(cases[1].value, isFalse);

    // Puis un montant qui déborde sur la cotisation : elle se recoche.
    await tester.enterText(_champMontant, '18000');
    await tester.pump();

    final apres = _cases(tester);
    expect(apres[0].value, isTrue);
    expect(apres[1].value, isTrue);
  });

  testWidgets('décocher une ligne réaligne le montant sur ce qui reste coché',
      (tester) async {
    await _ouvrirEtSelectionner(tester);

    // Décocher la recette : il ne reste que la cotisation, 5 000.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(_cases(tester)[0].value, isFalse);
    expect(find.text('5 000'), findsOneWidget);

    // Tout décocher : montant vidé, bouton « Encaisser » désactivé.
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();

    expect(find.text('Cochez au moins une ligne à encaisser'), findsOneWidget);
    final bouton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(bouton.onPressed, isNull);
  });

  // ── Soumission ────────────────────────────────────────────────────────────

  testWidgets(
      'recette et cotisation de jours différents : deux versements, '
      'la recette d\'abord', (tester) async {
    final versements = _FakeVersementRepo();
    await _ouvrirEtSelectionner(tester, versements: versements);

    await _encaisser(tester);

    // Pas de pièce de caisse commune : le serveur la refuserait.
    expect(versements.appels, [(1, null), (null, 2)]);
  });

  testWidgets('lignes du même jour et du même chauffeur : un seul versement',
      (tester) async {
    final versements = _FakeVersementRepo();
    await _ouvrirEtSelectionner(tester,
        jourCotisation: DateTime(2026, 9, 1), versements: versements);

    await _encaisser(tester);

    expect(versements.appels, [(1, 2)]);
  });

  testWidgets(
      'cotisation refusée après la recette : la recette quitte la feuille '
      'et un nouvel essai ne la rejoue pas', (tester) async {
    final versements = _FakeVersementRepo()
      ..refusCotisationSeule = 'La caisse a été comptée le 02/09/2026.';
    await _ouvrirEtSelectionner(tester, versements: versements);

    await _encaisser(tester);

    expect(versements.appels, [(1, null), (null, 2)]);
    expect(find.textContaining('Recette encaissée'), findsOneWidget);
    expect(find.textContaining('caisse a été comptée'), findsOneWidget);
    // Seule la cotisation reste à régler, montant réaligné sur elle.
    expect(_cases(tester), hasLength(1));
    expect(find.text('5 000'), findsOneWidget);

    versements.refusCotisationSeule = null;
    await _encaisser(tester);

    expect(versements.appels.last, (null, 2));
    expect(versements.appels.where((a) => a.$1 == 1), hasLength(1));
  });
}

/// La feuille dépasse la surface de test : le bouton est amené à l'écran avant
/// d'être touché.
Future<void> _encaisser(WidgetTester tester) async {
  final bouton = find.widgetWithText(FilledButton, 'Encaisser');
  await tester.ensureVisible(bouton);
  await tester.pumpAndSettle();
  await tester.tap(bouton);
  await tester.pumpAndSettle();
}

