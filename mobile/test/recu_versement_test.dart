import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/utils/recu_paiement.dart';
import 'package:vtc_manager/features/operation_financiere/domain/enums/mode_paiement.dart';
import 'package:vtc_manager/features/versement/domain/entities/versement.dart';
import 'package:vtc_manager/features/versement/presentation/recu_versement.dart';

/// Le reçu d'un versement couvre le billet entier : la recette et la cotisation
/// du jour sur un seul message, et ce qui reste dû sur les deux créances.
Versement _versement({
  double? resteRecette = 5000,
  double resteCotisation = 0,
  bool cotisationAnnulee = false,
}) =>
    Versement(
      versementId: 'v1',
      dateEncaissement: DateTime(2026, 9, 11),
      modePaiement: ModePaiement.ESPECES,
      chauffeurNom: 'Jean Kouassi',
      chauffeurTelephone: '0712345678',
      vehiculeImmatriculation: '1234 AB 01',
      total: cotisationAnnulee ? 15000 : 17000,
      imputations: [
        ImputationVersement(
          operationId: 501,
          reference: 'ENC-2026-000501',
          nature: NatureImputation.recette,
          libelle: 'Recette',
          dateReference: DateTime(2026, 9, 10),
          montant: 15000,
          resteDu: resteRecette,
        ),
        ImputationVersement(
          operationId: 502,
          nature: NatureImputation.cotisation,
          libelle: 'Cotisation carburant',
          dateReference: DateTime(2026, 9, 10),
          montant: 2000,
          annulee: cotisationAnnulee,
          resteDu: resteCotisation,
        ),
      ],
    );

void main() {
  test('les deux créances figurent au reçu, nommées comme le chauffeur les connaît',
      () {
    final texte = composerRecu(recuDuVersement(_versement()));

    expect(texte, contains('Recette du 10/09/2026'));
    expect(texte, contains('Cotisation carburant du 10/09/2026'));
    expect(texte, contains('Total reçu'));
    expect(texte, contains('Jean Kouassi'));
    expect(texte, contains('Mode : Espèces'));
    expect(texte, contains('Date : 11/09/2026'));
    expect(texte, contains('Reste dû'));
  });

  test('le reste dû cumule les deux créances', () {
    expect(_versement(resteRecette: 5000, resteCotisation: 1000).resteDu, 6000);
  });

  // Une recette au montant réel n'a pas de dû : additionner le reste de la
  // cotisation seule se lirait comme un solde complet.
  test('un reste inconnu sur une créance rend le solde inconnu', () {
    expect(_versement(resteRecette: null).resteDu, isNull);
    expect(composerRecu(recuDuVersement(_versement(resteRecette: null))),
        isNot(contains('Reste dû')));
  });

  test('une imputation extournée ne figure plus au reçu', () {
    final texte =
        composerRecu(recuDuVersement(_versement(cotisationAnnulee: true)));

    expect(texte, isNot(contains('Cotisation carburant')));
    expect(texte, contains('Montant reçu'));
  });
}
