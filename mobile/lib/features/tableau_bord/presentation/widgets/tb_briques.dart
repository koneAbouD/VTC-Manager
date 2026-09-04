import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Briques d'affichage du tableau de bord.
///
/// Un tableau de bord n'est pas une liste de nombres : c'est une hiérarchie de
/// lecture. Ces briques la portent — une carte par question (`TbSection`), un
/// chiffre dominant par carte (`TbKpiPrincipal`), des chiffres de contexte
/// autour (`TbKpiTuile`), et le détail en lignes (`TbLigneDetail`). L'œil
/// descend, il ne cherche pas.

/// Seuils de couleur communs : un taux se lit vert / orange / rouge, jamais
/// « bleu parce que ça fait joli ». Le sens précède l'esthétique.
const Color kTbVert = Color(0xFF2E7D32);
const Color kTbOrange = Color(0xFFE65100);
const Color kTbRouge = Color(0xFFC62828);
const Color kTbNeutre = Color(0xFF1A1A2E);

/// Couleur d'un taux dont la hausse est une bonne nouvelle (disponibilité,
/// recouvrement, couverture du point mort).
Color tbCouleurTauxCroissant(double? taux, {double bon = 80, double moyen = 60}) {
  if (taux == null) return kTbNeutre;
  if (taux >= bon) return kTbVert;
  if (taux >= moyen) return kTbOrange;
  return kTbRouge;
}

/// Couleur d'un taux dont la hausse est une mauvaise nouvelle (part de
/// créances anciennes, taux d'immobilisation, taux de charges).
Color tbCouleurTauxDecroissant(double? taux,
    {double bon = 10, double moyen = 25}) {
  if (taux == null) return kTbNeutre;
  if (taux <= bon) return kTbVert;
  if (taux <= moyen) return kTbOrange;
  return kTbRouge;
}

/// Couleur d'un montant selon son signe : un résultat négatif doit sauter aux
/// yeux sans qu'on ait à lire le signe.
Color tbCouleurMontant(double montant) =>
    montant < 0 ? kTbRouge : (montant > 0 ? kTbVert : kTbNeutre);

/// Montant en francs, forme courte pour les grands nombres (« 12,4 M »).
///
/// Un tableau de bord se lit d'un coup d'œil : « 12 350 000 XOF » oblige à
/// compter les chiffres, « 12,4 M » se saisit immédiatement. Le détail exact
/// reste disponible dans les états financiers.
String tbMontantCourt(double montant) {
  final abs = montant.abs();
  final signe = montant < 0 ? '-' : '';
  if (abs >= 1000000) {
    final v = abs / 1000000;
    return '$signe${v.toStringAsFixed(v >= 100 ? 0 : 1).replaceAll('.', ',')} M';
  }
  if (abs >= 10000) {
    final v = abs / 1000;
    return '$signe${v.toStringAsFixed(0)} k';
  }
  return CurrencyFormatter.format(montant).replaceAll('XOF', '').trim();
}

/// Montant complet, avec la devise. Pour les lignes de détail, où la précision
/// prime sur la vitesse de lecture.
String tbMontant(double montant) => CurrencyFormatter.format(montant);

/// Pourcentage, ou « — » quand le ratio n'a pas de base (dénominateur nul).
/// Écrire « 0 % » à la place ferait croire à une mesure ; il n'y en a pas.
String tbPourcent(double? valeur, {int decimales = 1}) {
  if (valeur == null) return '—';
  final arrondi = valeur.roundToDouble() == valeur ? 0 : decimales;
  return '${valeur.toStringAsFixed(arrondi).replaceAll('.', ',')} %';
}

/// Carte de section : un titre, une question en sous-titre, un contenu.
class TbSection extends StatelessWidget {
  final IconData icone;
  final String titre;

  /// La question à laquelle la section répond, en clair. Un tableau de bord
  /// dont on doit deviner l'intention n'est pas lu.
  final String question;

  final Color accent;
  final Widget child;

  /// Action optionnelle en haut à droite (ex. : « Voir le détail »).
  final Widget? action;

  const TbSection({
    super.key,
    required this.icone,
    required this.titre,
    required this.question,
    required this.child,
    this.accent = AppColors.primary,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark)),
                    Text(question,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.hint)),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Chiffre dominant d'une section : la réponse en un coup d'œil, avec sa
/// variation et une phrase qui dit ce qu'il faut en conclure.
class TbKpiPrincipal extends StatelessWidget {
  final String label;
  final String valeur;
  final Color couleur;

  /// Variation en % par rapport à la période précédente. Null = pas de base
  /// de comparaison, la pastille disparaît.
  final double? variationPct;

  /// Vrai quand une hausse est une bonne nouvelle. Une hausse des charges ne
  /// se peint pas en vert.
  final bool hausseFavorable;

  /// Lecture en clair sous le chiffre.
  final String? commentaire;

  const TbKpiPrincipal({
    super.key,
    required this.label,
    required this.valeur,
    required this.couleur,
    this.variationPct,
    this.hausseFavorable = true,
    this.commentaire,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.label)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  valeur,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: couleur,
                      height: 1.1),
                ),
              ),
            ),
            if (variationPct != null) ...[
              const SizedBox(width: 10),
              TbVariationPill(
                  valeur: variationPct!, hausseFavorable: hausseFavorable),
            ],
          ],
        ),
        if (commentaire != null) ...[
          const SizedBox(height: 4),
          Text(commentaire!,
              style: const TextStyle(fontSize: 11.5, color: AppColors.hint)),
        ],
      ],
    );
  }
}

/// Pastille de variation : flèche, valeur signée, couleur portant le jugement.
class TbVariationPill extends StatelessWidget {
  final double valeur;
  final bool hausseFavorable;

  const TbVariationPill({
    super.key,
    required this.valeur,
    this.hausseFavorable = true,
  });

  @override
  Widget build(BuildContext context) {
    final hausse = valeur >= 0;
    final favorable = hausse == hausseFavorable;
    final couleur = valeur.abs() < 0.05
        ? AppColors.hint
        : (favorable ? kTbVert : kTbRouge);
    final texte =
        '${hausse ? '+' : ''}${valeur.toStringAsFixed(1).replaceAll('.', ',')} %';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hausse ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 13, color: couleur),
          const SizedBox(width: 3),
          Text(texte,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: couleur)),
        ],
      ),
    );
  }
}

/// Petite tuile de contexte, posée en grille sous le chiffre dominant.
class TbKpiTuile extends StatelessWidget {
  final String label;
  final String valeur;
  final Color couleur;
  final String? sousLabel;

  /// Explication affichée à l'appui long : la définition du ratio. Un
  /// indicateur qu'on ne sait pas définir ne sert à rien.
  final String? aide;

  const TbKpiTuile({
    super.key,
    required this.label,
    required this.valeur,
    this.couleur = kTbNeutre,
    this.sousLabel,
    this.aide,
  });

  @override
  Widget build(BuildContext context) {
    final contenu = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.label),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valeur,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: couleur,
                    height: 1.1)),
          ),
          if (sousLabel != null) ...[
            const SizedBox(height: 3),
            Text(sousLabel!,
                style: const TextStyle(fontSize: 10.5, color: AppColors.hint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );

    if (aide == null) return contenu;
    return Tooltip(
      message: aide!,
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      child: contenu,
    );
  }
}

/// Grille de tuiles : deux colonnes en téléphone, quatre en écran large.
class TbGrilleTuiles extends StatelessWidget {
  final List<Widget> tuiles;
  final bool isWide;

  const TbGrilleTuiles({super.key, required this.tuiles, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final colonnes = isWide ? 4 : 2;
    final lignes = <Widget>[];
    for (var i = 0; i < tuiles.length; i += colonnes) {
      final tranche = tuiles.skip(i).take(colonnes).toList();
      lignes.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = 0; j < colonnes; j++) ...[
              if (j > 0) const SizedBox(width: 10),
              Expanded(
                  child: j < tranche.length
                      ? tranche[j]
                      : const SizedBox.shrink()),
            ],
          ],
        ),
      ));
      if (i + colonnes < tuiles.length) lignes.add(const SizedBox(height: 10));
    }
    return Column(children: lignes);
  }
}

/// Ligne de détail : libellé à gauche, valeur à droite, filet de séparation.
class TbLigneDetail extends StatelessWidget {
  final String libelle;
  final String valeur;
  final Color? couleurValeur;

  /// Met la ligne en avant (soldes intermédiaires : marge, EBE, résultat).
  final bool forte;

  final String? sousLibelle;

  const TbLigneDetail({
    super.key,
    required this.libelle,
    required this.valeur,
    this.couleurValeur,
    this.forte = false,
    this.sousLibelle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libelle,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: forte ? FontWeight.w700 : FontWeight.w500,
                        color: forte ? AppColors.dark : AppColors.label)),
                if (sousLibelle != null)
                  Text(sousLibelle!,
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.hint)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(valeur,
              style: TextStyle(
                  fontSize: forte ? 14 : 13,
                  fontWeight: forte ? FontWeight.w800 : FontWeight.w600,
                  color: couleurValeur ?? AppColors.dark)),
        ],
      ),
    );
  }
}

/// Filet de séparation entre lignes de détail.
class TbFilet extends StatelessWidget {
  const TbFilet({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.border);
}
