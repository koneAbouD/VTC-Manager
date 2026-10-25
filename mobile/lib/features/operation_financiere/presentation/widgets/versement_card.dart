import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/extourne_badge.dart';

import 'ligne_journal.dart';

import '../../../../core/theme/app_colors.dart';
/// Un versement dans le journal : le billet en tête, sa ventilation dessous.
///
/// Même gabarit que la tuile d'une écriture — pastille, libellé, montant, puis
/// véhicule et chauffeur — pour que la liste reste d'un seul tenant. S'ajoute
/// seulement la ligne qui dit ce que le billet a soldé, créance par créance.
class VersementCard extends StatelessWidget {
  final VersementRegroupe versement;
  final VoidCallback onTap;

  const VersementCard({super.key, required this.versement, required this.onTap});

  static Color get _vert => AppColors.positive;
  static Color get _encre => AppColors.dark;

  static TextStyle _barre(TextStyle style, bool barree) => barree
      ? style.copyWith(
          color: Colors.red,
          decoration: TextDecoration.lineThrough,
          decorationColor: Colors.red)
      : style;

  @override
  Widget build(BuildContext context) {
    final montant = NumberFormat('#,##0', 'fr_FR');
    final tete = versement.tete;
    final annule = versement.entierementAnnule;
    final extourne = versement.estExtourne;
    // La pastille prend la couleur de la contre-passation, comme son badge.
    final teinte = extourne ? Colors.orange.shade700 : _vert;

    // « Recette + Cotisation d'hier » : ce que le billet a soldé, puis la
    // journée réglée — la même date relative que sur une écriture seule.
    final natures = versement.ecritures
        .map((e) => e.categorieLibelle ?? 'Encaissement')
        .join(' + ');
    final titre = '$natures ${tete.libelleDateRelative}';

    final vehiculeChauffeur = [
      if (tete.vehiculeNom != null) tete.vehiculeNom!,
      if (tete.chauffeurNom != null) tete.chauffeurNom!,
    ].join(' - ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.blanc,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pastille de pièce de caisse : un billet, plusieurs écritures.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: teinte.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long_rounded,
                  color: teinte, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _barre(
                              TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _encre),
                              annule),
                        ),
                      ),
                      // « Extournée » sur le billet rendu, « Extourne » sur
                      // sa contre-passation : le même repère que les lignes
                      // d'une écriture seule.
                      ExtourneBadge(
                          estUneExtourne: extourne, estAnnulee: annule),
                      const SizedBox(width: 8),
                      Text(
                        '${montant.format(versement.total)} XOF',
                        style: _barre(
                            TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _encre),
                            annule),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vehiculeChauffeur,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: AppColors.grey500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM', 'fr_FR').format(tete.dateOperation),
                        style:
                            TextStyle(fontSize: 10, color: AppColors.grey400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Ventilation : une imputation extournée reste lisible,
                  // barrée — le billet a été remis, elle ne compte plus.
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      for (final e in versement.ecritures)
                        Text(
                          '${e.categorieLibelle ?? 'Encaissement'} '
                          '${montant.format(e.montant)}',
                          style: _barre(
                              TextStyle(
                                  fontSize: 11,
                                  color: AppColors.grey600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ]),
                              VersementRegroupe.estNeutralisee(e)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
