import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../screens/home_nav_provider.dart';
import '../../../etat_parc/presentation/providers/etat_parc_provider.dart';

/// Redirections du tableau de bord.
///
/// Le tableau de bord ne porte que la synthèse : chaque chiffre renvoie à
/// l'écran qui en tient le détail. Deux cas :
/// - l'écran est un onglet d'un hub (Finances, Flotte) : on règle l'onglet
///   voulu, puis on dépile jusqu'à l'accueil — empiler un second hub par-dessus
///   les Réglages laisserait deux barres de navigation l'une sur l'autre ;
/// - l'écran est une page autonome (compte de résultat, fiche, créances d'un
///   chauffeur) : on la pousse, le retour ramène au tableau de bord.

/// Index des onglets de la barre principale (voir [homeTabIndexProvider]).
const _navFlotte = 1;
const _navFinances = 3;

/// Ouvre un onglet du hub Finances. [typeOperation] (`REVENU` / `DEPENSE`)
/// filtre l'onglet Opérations à l'arrivée.
void tbOuvrirFinances(BuildContext context, WidgetRef ref, int onglet,
    {String? typeOperation}) {
  if (onglet == FinanceTab.operations) {
    ref.read(operationsTypeFiltreProvider.notifier).state = typeOperation;
  }
  ref.read(financeTabIndexProvider.notifier).state = onglet;
  ref.read(homeTabIndexProvider.notifier).state = _navFinances;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Ouvre un onglet du hub Flotte. Sur l'état de parc, [motif] restreint la
/// liste « véhicules demandant une action » à ce motif ; sans motif, elle
/// repart sur « Tous » plutôt que de garder un filtre posé auparavant.
void tbOuvrirFlotte(BuildContext context, WidgetRef ref, int onglet,
    {String? motif}) {
  if (onglet == FleetTab.etatParc) {
    ref.read(etatParcExceptionCritereProvider.notifier).state =
        ExceptionCritere(motif: motif);
  }
  ref.read(fleetTabIndexProvider.notifier).state = onglet;
  ref.read(homeTabIndexProvider.notifier).state = _navFlotte;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Pousse une page de détail au-dessus du tableau de bord.
void tbPousser(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
