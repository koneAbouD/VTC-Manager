import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:vtc_manager/core/error/failure.dart';
import 'package:vtc_manager/core/network/page_result.dart';
import 'package:vtc_manager/features/contravention/domain/entities/contravention.dart';
import 'package:vtc_manager/features/contravention/domain/repositories/contravention_repository.dart';
import 'package:vtc_manager/features/contravention/presentation/providers/contravention_provider.dart';
import 'package:vtc_manager/features/contravention/presentation/pages/contraventions_page.dart';

/// Repository factice : renvoie 3 contraventions « En attente » identifiables.
class _FakeRepo implements ContraventionRepository {
  List<Contravention> _data() => [
        Contravention(
            id: 1,
            dateInfraction: DateTime(2026, 7, 10),
            montant: 25000,
            statut: 'EN_ATTENTE',
            vehiculeNom: 'AA-111',
            chauffeurNom: 'Alpha',
            typeInfraction: 'Excès'),
        Contravention(
            id: 2,
            dateInfraction: DateTime(2026, 7, 11),
            montant: 15000,
            statut: 'EN_ATTENTE',
            vehiculeNom: 'BB-222',
            chauffeurNom: 'Bravo',
            typeInfraction: 'Feu rouge'),
        Contravention(
            id: 3,
            dateInfraction: DateTime(2026, 7, 12),
            montant: 30000,
            statut: 'EN_ATTENTE',
            vehiculeNom: 'CC-333',
            chauffeurNom: 'Charlie',
            typeInfraction: 'Stationnement'),
      ];

  @override
  Future<Either<Failure, PageResult<Contravention>>> getContraventionsPage({
    int page = 0,
    int size = 20,
    int? chauffeurId,
    int? vehiculeId,
    String? dateDebut,
    String? dateFin,
  }) async =>
      Right(PageResult<Contravention>(
        content: page == 0 ? _data() : const [],
        page: page,
        size: size,
        totalElements: 3,
        totalPages: 1,
        last: true,
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      contraventionRepositoryProvider.overrideWithValue(_FakeRepo()),
    ],
    child: const MaterialApp(home: ContraventionsPage(embedded: true)),
  ));
  // Laisse le microtask _load + le Future du repo se résoudre.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('les 3 lignes se chargent', (tester) async {
    await _pumpPage(tester);
    // Les 3 types d'infraction sont rendus ; aucune barre de sélection tant
    // qu'on n'a pas activé le mode sélection (appui long).
    expect(find.text('Excès'), findsOneWidget);
    expect(find.text('Feu rouge'), findsOneWidget);
    expect(find.text('Stationnement'), findsOneWidget);
    expect(find.text('Total à reverser'), findsNothing);
  });

  testWidgets('un appui long coche la ligne → barre Reverser (1) apparaît',
      (tester) async {
    await _pumpPage(tester);

    // Aucune barre de reversement au départ.
    expect(find.textContaining('Reverser ('), findsNothing);

    // La sélection s'active par appui long (le tap ouvre le détail).
    await tester.longPress(find.text('Feu rouge'));
    await tester.pump();

    // La barre basse « Total à reverser » + « Reverser (1) » doit apparaître.
    expect(find.text('Total à reverser'), findsOneWidget);
    expect(find.text('Reverser (1)'), findsOneWidget);
  });

  testWidgets('« Tout sélectionner » coche les 3 lignes → Reverser (3)',
      (tester) async {
    await _pumpPage(tester);

    // Entre en mode sélection (appui long), puis coche tout.
    await tester.longPress(find.text('Feu rouge'));
    await tester.pump();

    expect(find.text('3 contravention(s)'), findsOneWidget);
    await tester.tap(find.text('Tout sélectionner'));
    await tester.pump();

    expect(find.text('Reverser (3)'), findsOneWidget);
    // Le libellé du bouton de la barre d'outils bascule.
    expect(find.text('Annuler'), findsOneWidget);
  });
}
