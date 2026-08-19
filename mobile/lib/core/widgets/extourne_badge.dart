import 'package:flutter/material.dart';

/// Pastille de contre-passation posée sur les lignes d'opération (Accueil,
/// liste des opérations, rapport financier).
///
/// Deux marques à distinguer : l'écriture qui corrige porte « Extourne »
/// (orange), celle qu'elle neutralise porte « Extournée » (rouge) — cette
/// dernière reste au journal, barrée. Une écriture ordinaire ne rend rien, ce
/// qui permet de poser le badge sans condition dans une `Row`.
class ExtourneBadge extends StatelessWidget {
  /// Cette écriture est une contre-passation (montant opposé de l'origine).
  final bool estUneExtourne;

  /// Cette écriture a été contre-passée, ou porte l'ancien statut ANNULEE.
  final bool estAnnulee;

  const ExtourneBadge({
    super.key,
    required this.estUneExtourne,
    required this.estAnnulee,
  });

  @override
  Widget build(BuildContext context) {
    if (!estUneExtourne && !estAnnulee) return const SizedBox.shrink();

    final label = estUneExtourne ? 'Extourne' : 'Extournée';
    final color =
        estUneExtourne ? Colors.orange.shade700 : Colors.red.shade400;

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
