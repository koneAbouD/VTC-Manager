import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:vtc_manager/features/operation_financiere/domain/entities/operation_financiere.dart';
import 'package:vtc_manager/features/operation_financiere/domain/enums/mode_paiement.dart';
import 'package:vtc_manager/features/operation_financiere/domain/enums/type_operation.dart';
import 'package:vtc_manager/features/operation_financiere/presentation/pages/operation_financiere_detail_page.dart';
import 'package:vtc_manager/features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import 'package:vtc_manager/features/versement/domain/entities/versement.dart';
import 'package:vtc_manager/features/versement/presentation/providers/versement_provider.dart';

/// L'en-tête du détail d'une écriture : pour la recette ou la cotisation d'un
/// versement, il annonce le billet entier — ce que le guichet a reçu — et non
/// la seule part de l'écriture ouverte.
final _money =
    NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

String _encaisse(double montant) => '+${_money.format(montant)}';

OperationFinanciere _recette({String? versementId, DateTime? annuleLe}) =>
    OperationFinanciere(
      id: 501,
      reference: 'ENC-2026-000501',
      typeOperation: TypeOperation.REVENU,
      categorieCode: 'ENCAISSEMENT_RECETTES',
      categorieLibelle: 'Recette',
      chauffeurNom: 'Jean Kouassi',
      vehiculeNom: '1234 AB 01',
      montant: 15000,
      modePaiement: ModePaiement.ESPECES,
      dateOperation: DateTime(2026, 9, 11),
      dateReference: DateTime(2026, 9, 10),
      versementId: versementId,
      annuleLe: annuleLe,
    );

Versement _versement() => Versement(
      versementId: 'v1',
      dateEncaissement: DateTime(2026, 9, 11),
      modePaiement: ModePaiement.ESPECES,
      chauffeurNom: 'Jean Kouassi',
      vehiculeImmatriculation: '1234 AB 01',
      total: 17000,
      imputations: [
        ImputationVersement(
          operationId: 501,
          nature: NatureImputation.recette,
          libelle: 'Recette',
          dateReference: DateTime(2026, 9, 10),
          montant: 15000,
          resteDu: 0,
        ),
        ImputationVersement(
          operationId: 502,
          nature: NatureImputation.cotisation,
          libelle: 'Cotisation carburant',
          dateReference: DateTime(2026, 9, 10),
          montant: 2000,
          resteDu: 0,
        ),
      ],
    );

Future<void> _ouvrir(WidgetTester tester, OperationFinanciere op) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      operationFinanciereByIdProvider(op.id!).overrideWith((ref) async => op),
      versementProvider('v1').overrideWith((ref) async => _versement()),
    ],
    child: MaterialApp(home: OperationFinanciereDetailPage.parId(id: op.id!)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR', null));

  testWidgets('une écriture d\'un versement annonce la recette et la cotisation '
      'réunies, encaissées', (tester) async {
    await _ouvrir(tester, _recette(versementId: 'v1'));

    expect(find.text(_encaisse(17000)), findsOneWidget);
    expect(find.text(_encaisse(15000)), findsNothing);
    expect(find.text('Encaissée'), findsOneWidget);
  });

  testWidgets('une écriture isolée garde son propre montant', (tester) async {
    await _ouvrir(tester, _recette());

    expect(find.text(_encaisse(15000)), findsOneWidget);
  });

  // Extournée, l'écriture est ce que la correction concerne : annoncer le
  // billet entier ferait croire que la cotisation a été annulée avec elle.
  testWidgets('une écriture extournée d\'un versement garde son propre montant',
      (tester) async {
    await _ouvrir(
        tester, _recette(versementId: 'v1', annuleLe: DateTime(2026, 9, 12)));

    expect(find.text(_encaisse(15000)), findsOneWidget);
    expect(find.text(_encaisse(17000)), findsNothing);
  });
}
