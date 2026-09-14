import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/utils/libelle_operation.dart';

/// Sur un reçu destiné au chauffeur, c'est sa dette qu'il faut nommer, pas le
/// geste du guichet : « Recette du 10/09/2026 », et non « Encaissement
/// recettes ».
void main() {
  final jour = DateTime(2026, 9, 10);

  String libelle(String? code, {String? titre = 'Encaissement recettes'}) =>
      libelleCreanceEncaissee(
          categorieCode: code, categorieLibelle: titre, date: jour);

  test('chaque nature d\'encaissement est nommée côté chauffeur', () {
    expect(libelle('ENCAISSEMENT_RECETTES'), 'Recette du 10/09/2026');
    expect(libelle('ENCAISSEMENT_COTISATIONS'), 'Cotisation du 10/09/2026');
    expect(libelle('ENCAISSEMENT_PENALITES'), 'Pénalité du 10/09/2026');
  });

  test('le code est lu sans égard à la casse', () {
    expect(libelle('encaissement_recettes'), 'Recette du 10/09/2026');
  });

  test('une catégorie inconnue garde son libellé plutôt que de se taire', () {
    expect(libelle('AUTRE_CHOSE', titre: 'Rachat de créance'),
        'Rachat de créance du 10/09/2026');
  });

  test('sans rien pour nommer la créance, le reçu reste lisible', () {
    expect(libelle(null, titre: null), 'Versement du 10/09/2026');
  });
}
