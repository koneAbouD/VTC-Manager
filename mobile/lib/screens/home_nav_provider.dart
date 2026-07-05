import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onglet actif de la barre de navigation principale (HomeScreen).
/// 0 = Accueil, 1 = Flotte, 2 = Localisation, 3 = Finances.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

/// Sous-onglet actif du hub Finances (FinanceScreen).
/// 0 = Trésorerie, 1 = Créances, 2 = Opérations, 3 = Rapports.
final financeTabIndexProvider = StateProvider<int>((ref) => 0);

/// Filtre par type appliqué à l'onglet Opérations ('REVENU' / 'DEPENSE'),
/// null = tous. Permet à un autre écran (ex. « Tout afficher » du Rapport
/// financier) d'ouvrir l'onglet Opérations déjà filtré.
final operationsTypeFiltreProvider = StateProvider<String?>((ref) => null);
