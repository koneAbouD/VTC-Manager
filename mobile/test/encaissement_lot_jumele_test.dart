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

/// Consigne chaque envoi, et répond avec les verdicts qu'on lui donne.
class _Serveur {
  final List<List<VersementDeLigne>> envois = [];
  Either<Failure, List<({bool succes, String? message})>> Function(
      List<VersementDeLigne>) reponse = (versements) => Right([
        for (final _ in versements) (succes: true, message: null),
      ]);

  EnvoiVersements get envoyer => (versements, _) async {
        envois.add(versements);
        return reponse(versements).map((v) => verdictsParLigne(versements, v));
      };
}

void main() {
  test('sans créance du même jour, la journée part seule dans son versement',
      () async {
    final serveur = _Serveur();
    final executeur =
        ExecuteurLotJumele(lignes: const [_sansJumelle], envoyer: serveur.envoyer);

    final issue = await executeur.executer(_saisie({2: 8000}));

    final versement = serveur.envois.single.single;
    expect(versement.ligneId, 2);
    expect(versement.principal, 8000);
    expect(versement.jumelleId, isNull);
    expect(issue.reussies, {2});
    expect(issue.echecs, isEmpty);
  });

  test('le surplus au-delà de la recette voyage avec elle, dans le même versement',
      () async {
    final serveur = _Serveur();
    final executeur =
        ExecuteurLotJumele(lignes: const [_avecJumelle], envoyer: serveur.envoyer);

    // 18 000 : la recette prend ses 15 000, la cotisation les 3 000 restants.
    final issue = await executeur.executer(_saisie({1: 18000}));

    // Un seul envoi, une seule entrée : pas de second lot pour la sœur.
    final versement = serveur.envois.single.single;
    expect(versement.principal, 15000);
    expect(versement.jumelleId, 91);
    expect(versement.jumelle, 3000);
    expect(issue.reussies, {1});
  });

  test('panne réseau : rien n\'est parti, la feuille garde la saisie', () async {
    final serveur = _Serveur()
      ..reponse = (_) => const Left(NetworkFailure('Pas de connexion réseau.'));
    final executeur =
        ExecuteurLotJumele(lignes: const [_avecJumelle], envoyer: serveur.envoyer);

    final issue = await executeur.executer(_saisie({1: 18000}));

    expect(issue.erreurGlobale, 'Pas de connexion réseau.');
    expect(issue.reussies, isEmpty);
    expect(executeur.imputationsReussies, isEmpty);
  });

  test('versement refusé : ni la recette ni la cotisation ne sont retenues, '
      'et il repart entier', () async {
    final serveur = _Serveur()
      ..reponse = (versements) => Right([
            for (final _ in versements)
              (succes: false, message: 'La caisse a été comptée le 01/09/2026.'),
          ]);
    final executeur =
        ExecuteurLotJumele(lignes: const [_avecJumelle], envoyer: serveur.envoyer);

    final premier = await executeur.executer(_saisie({1: 18000}));

    expect(premier.reussies, isEmpty);
    expect(premier.echecs[1], contains('caisse a été comptée'));
    expect(executeur.imputationsReussies, isEmpty);

    // Rien n'étant passé, le second envoi reprend la journée en entier.
    await executeur.executer(_saisie({1: 18000}));
    expect(serveur.envois.last.single.principal, 15000);
    expect(serveur.envois.last.single.jumelle, 3000);
  });

  test('un versement accepté alimente le reçu, reste dû compris', () async {
    final serveur = _Serveur();
    final executeur =
        ExecuteurLotJumele(lignes: const [_avecJumelle], envoyer: serveur.envoyer);

    await executeur.executer(_saisie({1: 18000}));

    final imputation = executeur.imputationsReussies.single;
    expect(imputation.principal, 15000);
    expect(imputation.jumelle, 3000);
    // 5 000 de cotisation dus, 3 000 versés.
    expect(imputation.restant, 2000);
  });

  test('les verdicts du serveur reviennent à leur journée par leur ordre', () {
    const versements = [
      VersementDeLigne(ligneId: 1, principal: 15000, jumelleId: 91, jumelle: 3000),
      // Recette sans rien : tout est allé à la cotisation, le serveur ne
      // nomme donc pas la recette — seul l'ordre fait le lien.
      VersementDeLigne(ligneId: 2, principal: 0, jumelleId: 92, jumelle: 2000),
    ];

    final resultat = verdictsParLigne(versements, [
      (succes: true, message: null),
      (succes: false, message: 'Période clôturée'),
    ]);

    expect(resultat.reussis, 1);
    expect(resultat.echecs, 1);
    expect(resultat.resultats[1].ligneId, 2);
    expect(resultat.resultats[1].message, 'Période clôturée');
  });
}
