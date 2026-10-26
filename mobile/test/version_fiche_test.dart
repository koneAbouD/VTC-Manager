import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/chauffeur/data/models/chauffeur_request_model.dart';
import 'package:vtc_manager/features/chauffeur/domain/entities/chauffeur.dart';
import 'package:vtc_manager/features/vehicule/data/models/vehicule_model.dart';

/// La version lue avec la fiche repart avec la modification : c'est elle qui
/// permet au serveur de refuser une saisie faite sur une fiche périmée.
void main() {
  test('véhicule : la version lue repart avec la modification', () {
    final lu = VehiculeModel.fromJson({
      'id': 4,
      'version': 12,
      'immatriculation': 'AB-123',
      'marque': {'id': 1, 'nom': 'Toyota'},
      'modele': {'id': 2, 'nom': 'Yaris'},
    });

    final envoye = VehiculeModel.fromEntity(lu.copyWith(couleur: 'Rouge'));

    expect(envoye.toJson()['version'], 12);
  });

  test('véhicule : sans version connue, rien n\'est envoyé', () {
    final nouveau = VehiculeModel.fromJson({
      'immatriculation': 'AB-123',
      'marque': 'Toyota',
      'modele': 'Yaris',
    });

    expect(nouveau.toJson().containsKey('version'), isFalse);
  });

  test('chauffeur : la version de la fiche part dans la partie data', () {
    const fiche = Chauffeur(id: 3, version: 7, nom: 'Kouassi', prenom: 'Awa');

    final data = ChauffeurRequestModel.fromChauffeur(fiche)
        .copyWith(deletePhoto: true)
        .toJson();

    expect(data['version'], 7);
    expect(data['deletePhoto'], isTrue);
  });
}
