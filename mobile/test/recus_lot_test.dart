import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/widgets/encaissement_ligne_dialog.dart'
    show ModeEncaissementSaisie;
import 'package:vtc_manager/core/widgets/encaissement_lot_dialog.dart';
import 'package:vtc_manager/features/recette/domain/entities/ligne_recette.dart';
import 'package:vtc_manager/screens/finance/encaissement_lot_jumele.dart';
import 'package:vtc_manager/screens/finance/recus_lot.dart';

/// Les reçus d'un encaissement de masse. Ce que le lot a **accepté** fait foi :
/// une créance refusée ne doit figurer sur aucun reçu, et un chauffeur qui
/// solde plusieurs journées d'un seul versement n'en reçoit qu'un.
void main() {
  LigneRecette ligne({
    required int id,
    required int chauffeurId,
    String? nom = 'Kouassi Jean',
    String? telephone = '0712345678',
    String? immatriculation = '1234 AB 01',
    int jour = 10,
  }) =>
      LigneRecette(
        id: id,
        vehiculeId: 1,
        vehiculeImmatriculation: immatriculation,
        chauffeurId: chauffeurId,
        chauffeurNom: nom,
        chauffeurTelephone: telephone,
        dateRecette: DateTime(2026, 9, jour),
        montantEncaisse: 0,
        statut: StatutLigneRecette.enAttente,
      );

  final saisie = SaisieLot(
    lignes: const [],
    mode: ModeEncaissementSaisie.especes,
    reference: null,
    date: DateTime(2026, 9, 11),
    commentaire: null,
  );

  test('un chauffeur qui solde trois journées ne reçoit qu\'un reçu', () {
    final lignes = [
      ligne(id: 1, chauffeurId: 7, jour: 8),
      ligne(id: 2, chauffeurId: 7, jour: 9),
      ligne(id: 3, chauffeurId: 7, jour: 10),
    ];

    final recus = recusDuLot(
      lignes: lignes,
      jumelles: const {},
      imputations: const [
        ImputationLot(ligneId: 1, principal: 15000, jumelle: 0, restant: 0),
        ImputationLot(ligneId: 2, principal: 15000, jumelle: 0, restant: 0),
        ImputationLot(ligneId: 3, principal: 10000, jumelle: 0, restant: 5000),
      ],
      saisie: saisie,
    );

    expect(recus, hasLength(1));
    expect(recus.single.telephone, '0712345678');
    expect(recus.single.resume, contains('3 journées'));
    // Les trois journées sont nommées, et le reste dû cumulé annoncé.
    expect(recus.single.message, contains('Recette du 08/09/2026'));
    expect(recus.single.message, contains('Recette du 09/09/2026'));
    expect(recus.single.message, contains('Recette du 10/09/2026'));
    expect(recus.single.message, contains('Reste dû'));
  });

  test('chaque chauffeur a son propre reçu', () {
    final recus = recusDuLot(
      lignes: [
        ligne(id: 1, chauffeurId: 7, nom: 'Kouassi Jean'),
        ligne(id: 2, chauffeurId: 8, nom: 'Traoré Awa', telephone: '0587654321'),
      ],
      jumelles: const {},
      imputations: const [
        ImputationLot(ligneId: 1, principal: 15000, jumelle: 0, restant: 0),
        ImputationLot(ligneId: 2, principal: 12000, jumelle: 0, restant: 0),
      ],
      saisie: saisie,
    );

    expect(recus, hasLength(2));
    expect(recus.map((r) => r.nom), containsAll(['Kouassi Jean', 'Traoré Awa']));
    expect(recus.firstWhere((r) => r.nom == 'Traoré Awa').telephone,
        '0587654321');
  });

  test('la cotisation soldée du même jour figure au reçu', () {
    final recus = recusDuLot(
      lignes: [ligne(id: 1, chauffeurId: 7)],
      jumelles: const {
        1: JumelleLot(id: 90, libelle: 'Cotisation carburant', restant: 2000)
      },
      imputations: const [
        ImputationLot(ligneId: 1, principal: 15000, jumelle: 2000, restant: 0),
      ],
      saisie: saisie,
    );

    expect(recus.single.message, contains('Recette du 10/09/2026'));
    expect(recus.single.message, contains('Cotisation carburant du 10/09/2026'));
    expect(recus.single.message, contains('Total reçu'));
  });

  // Une période close ou une caisse comptée fait refuser la ligne : rien n'a
  // été encaissé, il n'y a rien à attester.
  test('une créance refusée n\'apparaît sur aucun reçu', () {
    final recus = recusDuLot(
      lignes: [
        ligne(id: 1, chauffeurId: 7),
        ligne(id: 2, chauffeurId: 8, nom: 'Traoré Awa', jour: 9),
      ],
      jumelles: const {},
      imputations: const [
        ImputationLot(ligneId: 1, principal: 15000, jumelle: 0, restant: 0),
      ],
      saisie: saisie,
    );

    expect(recus, hasLength(1));
    expect(recus.single.nom, 'Kouassi Jean');
  });

  test('aucune imputation acceptée ne produit aucun reçu', () {
    expect(
      recusDuLot(
        lignes: [ligne(id: 1, chauffeurId: 7)],
        jumelles: const {},
        imputations: const [],
        saisie: saisie,
      ),
      isEmpty,
    );
  });

  // Un chauffeur qui a tourné sur deux voitures ne doit pas en voir une seule
  // portée sur son reçu.
  test('le véhicule n\'est nommé que s\'il est le même partout', () {
    final unSeul = recusDuLot(
      lignes: [
        ligne(id: 1, chauffeurId: 7, jour: 8),
        ligne(id: 2, chauffeurId: 7, jour: 9),
      ],
      jumelles: const {},
      imputations: const [
        ImputationLot(ligneId: 1, principal: 15000, jumelle: 0, restant: 0),
        ImputationLot(ligneId: 2, principal: 15000, jumelle: 0, restant: 0),
      ],
      saisie: saisie,
    );
    expect(unSeul.single.message, contains('1234 AB 01'));

    final deux = recusDuLot(
      lignes: [
        ligne(id: 1, chauffeurId: 7, jour: 8),
        ligne(id: 2, chauffeurId: 7, jour: 9, immatriculation: '5678 CD 01'),
      ],
      jumelles: const {},
      imputations: const [
        ImputationLot(ligneId: 1, principal: 15000, jumelle: 0, restant: 0),
        ImputationLot(ligneId: 2, principal: 15000, jumelle: 0, restant: 0),
      ],
      saisie: saisie,
    );
    expect(deux.single.message, isNot(contains('Véhicule :')));
  });

  test('une fiche sans numéro produit quand même le reçu', () {
    final recus = recusDuLot(
      lignes: [ligne(id: 1, chauffeurId: 7, telephone: null)],
      jumelles: const {},
      imputations: const [
        ImputationLot(ligneId: 1, principal: 15000, jumelle: 0, restant: 0),
      ],
      saisie: saisie,
    );

    expect(recus, hasLength(1));
    expect(recus.single.telephone, isNull);
  });
}
