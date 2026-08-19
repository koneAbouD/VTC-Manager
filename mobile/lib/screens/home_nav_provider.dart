import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onglet actif de la barre de navigation principale (HomeScreen).
/// 0 = Accueil, 1 = Flotte, 2 = Localisation, 3 = Finances.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

/// Index des sous-onglets du hub Flotte. Doit refléter l'ordre des onglets
/// déclarés dans FleetScreen, dont les pastilles vivent dans l'en-tête
/// (HomeScreen) : le provider est le seul lien entre les deux.
abstract final class FleetTab {
  static const etatParc = 0;
  static const vehicules = 1;
  static const chauffeurs = 2;
}

/// Sous-onglet actif du hub Flotte (FleetScreen). Voir [FleetTab].
final fleetTabIndexProvider = StateProvider<int>((ref) => FleetTab.etatParc);

/// Index des sous-onglets du hub Finances. Doit refléter l'ordre des onglets
/// déclarés dans FinanceScreen : toute insertion d'onglet décale les suivants,
/// et les écrans qui pilotent [financeTabIndexProvider] passent par ces
/// constantes plutôt que par un littéral.
abstract final class FinanceTab {
  static const tresorerie = 0;
  static const creances = 1;
  static const partenaires = 2;
  static const operations = 3;
  static const rapports = 4;
}

/// Sous-onglet actif du hub Finances (FinanceScreen). Voir [FinanceTab].
final financeTabIndexProvider =
    StateProvider<int>((ref) => FinanceTab.tresorerie);

/// Vrai quand la ligne « montant du solde + bouton Encaisser » de la carte
/// (Accueil) est sortie de l'écran par le haut : l'en-tête prend alors le
/// relais. Piloté par le scroll d'AccueilScreen, seul lien avec HomeScreen qui
/// porte l'en-tête.
final soldeHorsEcranProvider = StateProvider<bool>((ref) => false);

/// Solde de la carte de l'Accueil, toujours en clair : montant formaté, ou
/// « … » au premier chargement d'une période. Publié par la carte pour que
/// l'en-tête le reprenne sans refaire ni le calcul de période ni le formatage.
///
/// Le masquage de l'œil n'est volontairement pas appliqué ici : la carte est
/// recyclée par la liste dès qu'elle sort de l'écran et ne republie donc plus
/// rien. Un texte déjà masqué figerait le montant repris dans l'en-tête, dont
/// l'œil ne changerait plus que d'icône. Chaque côté applique le masque
/// lui-même à partir de [soldeVisibleProvider].
final soldeAccueilTexteProvider = StateProvider<String>((ref) => '');

/// Œil de la carte solde : montants en clair ou masqués. Hissé hors du widget
/// pour que l'œil repris dans l'en-tête pilote le même état — un solde démasqué
/// d'un côté et caché de l'autre n'aurait aucun sens.
final soldeVisibleProvider = StateProvider<bool>((ref) => false);

/// Filtre par type appliqué à l'onglet Opérations ('REVENU' / 'DEPENSE'),
/// null = tous. Permet à un autre écran (ex. « Tout afficher » du Rapport
/// financier) d'ouvrir l'onglet Opérations déjà filtré.
final operationsTypeFiltreProvider = StateProvider<String?>((ref) => null);
