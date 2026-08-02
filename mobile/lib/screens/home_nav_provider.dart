import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onglet actif de la barre de navigation principale (HomeScreen).
/// 0 = Accueil, 1 = Flotte, 2 = Localisation, 3 = Finances.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

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

/// Filtre par type appliqué à l'onglet Opérations ('REVENU' / 'DEPENSE'),
/// null = tous. Permet à un autre écran (ex. « Tout afficher » du Rapport
/// financier) d'ouvrir l'onglet Opérations déjà filtré.
final operationsTypeFiltreProvider = StateProvider<String?>((ref) => null);
