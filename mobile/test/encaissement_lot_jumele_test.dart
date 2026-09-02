import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:vtc_manager/core/error/failure.dart';
import 'package:vtc_manager/core/models/encaissement_lot.dart';
import 'package:vtc_manager/core/widgets/encaissement_ligne_dialog.dart'
    show ModeEncaissementSaisie;
import 'package:vtc_manager/core/widgets/encaissement_lot_dialog.dart';
import 'package:vtc_manager/screens/finance/encaissement_lot_jumele.dart';

/// Deux journées : la première porte une cotisation du même jour, la seconde
/// non. La recette du 01/09 vaut 15 000, sa cotisation 5 000.
const _avecJumelle = LigneLotEncaissable(
  id: 1,
  titre: 'AA-111 - Alpha',
  sousTitre: 'Recette du 01/09/2026',
  restant: 15000,
  jumelle: JumelleLot(id: 91, libelle: 'Épargne', restant: 5000),
);

const _sansJumelle = LigneLotEncaissable(
  id: 2,
  titre: 'BB-222 - Bravo',
  sousTitre: 'Recette du 01/09/2026',
  restant: 8000,
);

SaisieLot _saisie(Map<int, double> montants) => SaisieLot(
      lignes: [
        for (final e in montants.entries)
          MontantLigne(ligneId: e.key, montant: e.value),
      ],
      mode: ModeEncaissementSaisie.especes,
      reference: null,
      date: DateTime(2026, 9, 2),
      commentaire: null,
    );

ResultatEncaissementLot _succes(List<MontantLigne> imputations) =>
    ResultatEncaissementLot(
      reussis: imputations.length,
      echecs: 0,
      resultats: [
        for (final i in imputations)
          ResultatLigneLot(ligneId: i.ligneId, succes: true, encaissementId: 1),
      ],
    );

ResultatEncaissementLot _refus(List<MontantLigne> imputations, String motif) =>
    ResultatEncaissementLot(
      reussis: 0,
      echecs: imputations.length,
      resultats: [
        for (final i in imputations)
          ResultatLigneLot(ligneId: i.ligneId, succes: false, message: motif),
      ],
    );

/// Consigne ce que chaque endpoint a reçu.
class _Envois {
  final List<List<MontantLigne>> principal = [];
  final List<List<MontantLigne>> jumelle = [];
}

void main() {
  test('sans créance du même jour, tout part dans le lot de la nature affichée',
      () async {
    final envois = _Envois();
    final executeur = ExecuteurLotJumele(
      lignes: const [_sansJumelle],
      envoyerPrincipal: (imputations, _) async {
        envois.principal.add(imputations);
        return Right(_succes(imputations));
      },
      envoyerJumelle: (imputations, _) async {
        envois.jumelle.add(imputations);
        return Right(_succes(imputations));
      },
    );

    final issue = await executeur.executer(_saisie({2: 8000}));

    expect(envois.principal.single.single.montant, 8000);
    expect(envois.jumelle, isEmpty);
    expect(issue.reussies, {2});
    expect(issue.echecs, isEmpty);
  });

  test('le surplus au-delà de la recette part sur la cotisation du jour',
      () async {
    final envois = _Envois();
    final executeur = ExecuteurLotJumele(
      lignes: const [_avecJumelle],
      envoyerPrincipal: (imputations, _) async {
        envois.principal.add(imputations);
        return Right(_succes(imputations));
      },
      envoyerJumelle: (imputations, _) async {
        envois.jumelle.add(imputations);
        return Right(_succes(imputations));
      },
    );

    // 18 000 : la recette prend ses 15 000, la cotisation les 3 000 restants.
    final issue = await executeur.executer(_saisie({1: 18000}));

    expect(envois.principal.single.single.montant, 15000);
    expect(envois.jumelle.single.single.ligneId, 91);
    expect(envois.jumelle.single.single.montant, 3000);
    expect(issue.reussies, {1});
  });

  test('le lot principal en panne n\'envoie rien sur la créance sœur',
      () async {
    final envois = _Envois();
    final executeur = ExecuteurLotJumele(
      lignes: const [_avecJumelle],
      envoyerPrincipal: (_, __) async =>
          const Left(NetworkFailure('Pas de connexion réseau.')),
      envoyerJumelle: (imputations, _) async {
        envois.jumelle.add(imputations);
        return Right(_succes(imputations));
      },
    );

    final issue = await executeur.executer(_saisie({1: 18000}));

    expect(envois.jumelle, isEmpty);
    expect(issue.erreurGlobale, 'Pas de connexion réseau.');
    expect(issue.reussies, isEmpty);
  });

  test('cotisation refusée : la recette passée n\'est pas rejouée', () async {
    final envois = _Envois();
    final executeur = ExecuteurLotJumele(
      lignes: const [_avecJumelle],
      envoyerPrincipal: (imputations, _) async {
        envois.principal.add(imputations);
        return Right(_succes(imputations));
      },
      envoyerJumelle: (imputations, _) async {
        envois.jumelle.add(imputations);
        return Right(_refus(imputations, 'Caisse déjà comptée'));
      },
    );

    final premier = await executeur.executer(_saisie({1: 18000}));

    expect(premier.reussies, isEmpty);
    expect(premier.echecs[1], contains('Épargne : Caisse déjà comptée'));
    // Il ne reste que la cotisation à imputer : la recette est soldée.
    expect(premier.restantsAjustes[1], 5000);

    // Second envoi sur ce reste : la recette ne repart pas.
    final second = await executeur.executer(_saisie({1: 5000}));

    expect(envois.principal, hasLength(1));
    expect(envois.jumelle.last.single.montant, 5000);
    expect(second.echecs[1], isNotNull);
  });

  test('panne sur le lot des créances sœurs : le motif suit la ligne',
      () async {
    final executeur = ExecuteurLotJumele(
      lignes: const [_avecJumelle],
      envoyerPrincipal: (imputations, _) async => Right(_succes(imputations)),
      envoyerJumelle: (_, __) async =>
          const Left(NetworkFailure('Pas de connexion réseau.')),
    );

    final issue = await executeur.executer(_saisie({1: 20000}));

    expect(issue.erreurGlobale, 'Pas de connexion réseau.');
    expect(issue.echecs[1], contains('Pas de connexion réseau.'));
    // La recette est passée : seul le reliquat de cotisation reste dû.
    expect(issue.restantsAjustes[1], 5000);
  });

  test('une recette refusée n\'empêche pas la cotisation du même jour',
      () async {
    final executeur = ExecuteurLotJumele(
      lignes: const [_avecJumelle],
      envoyerPrincipal: (imputations, _) async =>
          Right(_refus(imputations, 'Période comptable clôturée')),
      envoyerJumelle: (imputations, _) async => Right(_succes(imputations)),
    );

    final issue = await executeur.executer(_saisie({1: 20000}));

    expect(issue.echecs[1], contains('Période comptable clôturée'));
    // La cotisation, elle, est encaissée : il ne reste que la recette.
    expect(issue.restantsAjustes[1], 15000);
  });
}
