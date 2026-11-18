import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Étape à compléter avant de choisir les éléments d'une maintenance.
enum PrerequisElements { types, vehicule }

/// Feuille affichée quand on veut choisir les éléments d'une maintenance
/// avant d'en avoir fixé les types ou le véhicule.
///
/// Ce n'est pas une erreur : le catalogue proposé dépend de ces deux choix
/// (pièces du modèle du véhicule, éléments des types retenus). La feuille dit
/// donc où l'on en est — ce qui est fait, ce qui manque — et mène droit à
/// l'étape manquante.
///
/// Retourne l'étape choisie, ou `null` si la feuille est refermée.
Future<PrerequisElements?> showPrerequisElementsSheet(
  BuildContext context, {
  required String? typesLibelle,
  required String? vehiculeLibelle,
}) {
  return showModalBottomSheet<PrerequisElements>(
    context: context,
    // Hauteur du contenu, et non le plafond par défaut (9/16 de l'écran) qui
    // tronquait la feuille sur un petit téléphone.
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _PrerequisSheet(
      typesLibelle: typesLibelle,
      vehiculeLibelle: vehiculeLibelle,
    ),
  );
}

class _PrerequisSheet extends StatelessWidget {
  final String? typesLibelle;
  final String? vehiculeLibelle;

  const _PrerequisSheet({
    required this.typesLibelle,
    required this.vehiculeLibelle,
  });

  bool get _typesFaits => typesLibelle != null;
  bool get _vehiculeFait => vehiculeLibelle != null;

  /// La première étape manquante, dans l'ordre du formulaire.
  PrerequisElements get _prochaine =>
      _typesFaits ? PrerequisElements.vehicule : PrerequisElements.types;

  @override
  Widget build(BuildContext context) {
    final restantes = (_typesFaits ? 0 : 1) + (_vehiculeFait ? 0 : 1);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 10, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.checklist_rounded,
                  size: 28, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            restantes > 1 ? 'Encore deux étapes' : 'Encore une étape',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
                letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Les éléments proposés dépendent des types de maintenance et des '
            'pièces du véhicule.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.label),
          ),
          const SizedBox(height: 18),
          _Etape(
            numero: 1,
            titre: 'Types de maintenance',
            detail: typesLibelle ?? 'À choisir',
            fait: _typesFaits,
            onTap: () => Navigator.pop(context, PrerequisElements.types),
          ),
          const SizedBox(height: 8),
          _Etape(
            numero: 2,
            titre: 'Véhicule concerné',
            detail: vehiculeLibelle ?? 'À choisir',
            fait: _vehiculeFait,
            onTap: () => Navigator.pop(context, PrerequisElements.vehicule),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, _prochaine),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(
                  _prochaine == PrerequisElements.vehicule
                      ? Icons.directions_car_outlined
                      : Icons.category_outlined,
                  size: 18),
              label: Text(
                  _prochaine == PrerequisElements.vehicule
                      ? 'Choisir le véhicule'
                      : 'Choisir les types',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.label),
            child: const Text('Plus tard',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Une étape : faite (coche verte, choix rappelé) ou à faire (numéro,
/// chevron — toute la ligne y mène).
class _Etape extends StatelessWidget {
  final int numero;
  final String titre;
  final String detail;
  final bool fait;
  final VoidCallback onTap;

  const _Etape({
    required this.numero,
    required this.titre,
    required this.detail,
    required this.fait,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fait ? AppColors.fieldFill : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: fait ? Colors.transparent : AppColors.primary, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: fait ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fait ? AppColors.success : Colors.transparent,
                border: fait
                    ? null
                    : Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: fait
                  ? const Icon(Icons.check_rounded,
                      size: 17, color: Colors.white)
                  : Text('$numero',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark)),
                  const SizedBox(height: 2),
                  Text(detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: fait ? AppColors.label : AppColors.primary,
                          fontWeight:
                              fait ? FontWeight.w500 : FontWeight.w600)),
                ],
              ),
            ),
            if (!fait)
              Icon(Icons.chevron_right_rounded,
                  size: 22, color: AppColors.primary),
          ]),
        ),
      ),
    );
  }
}
