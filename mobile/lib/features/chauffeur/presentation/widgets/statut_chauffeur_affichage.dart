import 'package:flutter/material.dart';

import '../../domain/entities/chauffeur.dart';
import '../../domain/enums/chauffeur_status.dart';

/// Couleur du point posé devant un libellé de statut chauffeur.
///
/// Les pastilles de statut sont toutes grises : le fond ne distingue plus rien,
/// c'est le point qui porte l'état. Une teinte par état, jamais deux fois la
/// même — le libellé lève le reste de l'ambiguïté.
abstract final class PointStatutChauffeur {
  /// En service et attendu au volant aujourd'hui.
  static const auVolant = Color(0xFF2E7D32);

  /// En service mais pas au planning du jour : c'est le tour de son binôme, ou
  /// son véhicule ne roule pas aujourd'hui.
  static const auRepos = Color(0xFFC62828);

  /// Actif sans véhicule affecté : disponible, en attente d'une affectation.
  /// Le bleu que « En service » portait avant de passer au gris.
  static const disponible = Color(0xFF1565C0);

  /// En congé — absence connue et datée, d'où l'ambre des indisponibilités.
  static const enConge = Color(0xFFE65100);

  /// Suspendu — décision humaine. Le pourpre le sépare du rouge du repos : la
  /// sanction et le tour de repos n'ont rien à voir.
  static const suspendu = Color(0xFF6A1B9A);

  /// Inactif — sorti de l'effectif, rien à en attendre aujourd'hui.
  static const inactif = Color(0xFF9E9E9E);
}

/// Ce qu'une pastille montre d'un chauffeur : le libellé du moment et le point
/// qui le porte.
///
/// Un seul endroit pour la règle, que la pastille soit celle de la liste de la
/// flotte ou celle de la fiche — les deux doivent dire la même chose du même
/// chauffeur au même instant.
class StatutChauffeurAffichage {
  final String libelle;

  /// Nul quand aucun point n'a de sens : statut inconnu, ou chauffeur en
  /// service dont le serveur n'a pas dit s'il roule aujourd'hui. L'appelant
  /// garde alors son icône plutôt que d'inventer une couleur.
  final Color? point;

  const StatutChauffeurAffichage({required this.libelle, this.point});

  /// « En service » se dédouble selon le planning du jour : au volant, ou au
  /// repos. Les autres statuts se lisent seuls.
  factory StatutChauffeurAffichage.of(Chauffeur chauffeur) {
    if (chauffeur.statut == ChauffeurStatus.enService) {
      return switch (chauffeur.auProgrammeAujourdhui) {
        true => const StatutChauffeurAffichage(
            libelle: 'En service', point: PointStatutChauffeur.auVolant),
        false => const StatutChauffeurAffichage(
            libelle: 'Au repos', point: PointStatutChauffeur.auRepos),
        null => const StatutChauffeurAffichage(libelle: 'En service'),
      };
    }
    return switch (chauffeur.statut) {
      ChauffeurStatus.actif => const StatutChauffeurAffichage(
          libelle: 'Actif', point: PointStatutChauffeur.disponible),
      ChauffeurStatus.enConge => const StatutChauffeurAffichage(
          libelle: 'En congé', point: PointStatutChauffeur.enConge),
      ChauffeurStatus.suspendu => const StatutChauffeurAffichage(
          libelle: 'Suspendu', point: PointStatutChauffeur.suspendu),
      ChauffeurStatus.inactif => const StatutChauffeurAffichage(
          libelle: 'Inactif', point: PointStatutChauffeur.inactif),
      _ => const StatutChauffeurAffichage(libelle: 'Inconnu'),
    };
  }
}
