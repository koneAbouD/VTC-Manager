import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/operation_financiere/domain/entities/operation_financiere.dart';
import 'package:vtc_manager/features/operation_financiere/domain/enums/type_operation.dart';
import 'package:vtc_manager/features/operation_financiere/presentation/widgets/ligne_journal.dart';

/// Le journal montré au guichet : les écritures d'un même billet se lisent en
/// une ligne. Seule la clé de versement fait foi — le serveur garantit qu'elle
/// désigne encore un seul versement.
OperationFinanciere _op(
  int id, {
  String? versement,
  String code = 'ENCAISSEMENT_RECETTES',
  String libelle = 'Recette',
  double montant = 15000,
  DateTime? annuleLe,
}) =>
    OperationFinanciere(
      id: id,
      typeOperation: TypeOperation.REVENU,
      categorieCode: code,
      categorieLibelle: libelle,
      montant: montant,
      dateOperation: DateTime(2026, 9, 11),
      versementId: versement,
      annuleLe: annuleLe,
    );

OperationFinanciere _cotisation(int id, {String? versement, DateTime? annuleLe}) =>
    _op(id,
        versement: versement,
        code: 'ENCAISSEMENT_COTISATIONS',
        libelle: 'Cotisation',
        montant: 2000,
        annuleLe: annuleLe);

void main() {
  test('deux écritures du même versement forment une seule ligne, recette d\'abord',
      () {
    final lignes = regrouperParVersement([
      _cotisation(12, versement: 'v1'),
      _op(11, versement: 'v1'),
    ]);

    expect(lignes, hasLength(1));
    final versement = lignes.single as VersementRegroupe;
    expect(versement.ecritures.map((e) => e.id), [11, 12]);
    expect(versement.total, 17000);
  });

  test('les écritures isolées gardent leur place et leur ordre', () {
    final lignes = regrouperParVersement([
      _op(30),
      _op(21, versement: 'v2'),
      _cotisation(22, versement: 'v2'),
      _op(10),
    ]);

    expect(lignes.map((l) => l.runtimeType),
        [EcritureSeule, VersementRegroupe, EcritureSeule]);
    expect((lignes.first as EcritureSeule).operation.id, 30);
    expect((lignes.last as EcritureSeule).operation.id, 10);
  });

  // Deux écritures d'un même billet ne sont pas toujours voisines : une saisie
  // concurrente peut s'intercaler, ou la page suivante apporter la sœur.
  test('un versement se rassemble à la place de sa première écriture, même disjoint',
      () {
    final lignes = regrouperParVersement([
      _op(41, versement: 'v3'),
      _op(50),
      _cotisation(42, versement: 'v3'),
    ]);

    expect(lignes, hasLength(2));
    expect(lignes.first, isA<VersementRegroupe>());
    expect((lignes.last as EcritureSeule).operation.id, 50);
  });

  // Filtre « Cotisations » actif, ou sœur pas encore chargée : on ne montre pas
  // une pièce de caisse amputée d'une moitié.
  test('une écriture dont la sœur n\'est pas à l\'écran reste une écriture seule',
      () {
    final lignes = regrouperParVersement([_cotisation(62, versement: 'v4')]);

    expect(lignes.single, isA<EcritureSeule>());
  });

  test('une imputation extournée reste au versement mais sort de son total', () {
    final lignes = regrouperParVersement([
      _op(71, versement: 'v5'),
      _cotisation(72, versement: 'v5', annuleLe: DateTime(2026, 9, 12)),
    ]);

    final versement = lignes.single as VersementRegroupe;
    expect(versement.ecritures, hasLength(2));
    expect(versement.total, 15000);
    expect(versement.entierementAnnule, isFalse);
  });

  test('un versement entièrement extourné garde son montant, barré à l\'écran', () {
    final lignes = regrouperParVersement([
      _op(81, versement: 'v6', annuleLe: DateTime(2026, 9, 12)),
      _cotisation(82, versement: 'v6', annuleLe: DateTime(2026, 9, 12)),
    ]);

    final versement = lignes.single as VersementRegroupe;
    expect(versement.entierementAnnule, isTrue);
    expect(versement.total, 17000);
  });
}
