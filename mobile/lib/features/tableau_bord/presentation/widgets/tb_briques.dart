import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Briques d'affichage du tableau de bord.
///
/// Un tableau de bord n'est pas une liste de nombres : c'est une hiérarchie de
/// lecture. Ces briques la portent — une carte par question (`TbSection`), un
/// chiffre dominant par carte (`TbKpiPrincipal`, `TbJauge`), des chiffres de
/// contexte autour (`TbKpiTuile`). Le détail ligne à ligne n'est pas ici : il
/// vit dans l'écran que chaque lien (`TbLienVoir`, `TbLigneLien`) ouvre.
/// L'œil descend, il ne cherche pas.

/// Seuils de couleur communs : un taux se lit vert / orange / rouge, jamais
/// « bleu parce que ça fait joli ». Le sens précède l'esthétique.
Color get kTbVert => AppColors.positive;
Color get kTbOrange => AppColors.warning;
Color get kTbRouge => AppColors.error;
Color get kTbNeutre => AppColors.dark;

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

/// Carte de section : pastille d'icône, titre, et à droite le lien vers
/// l'écran qui tient le détail. La section ne montre que la synthèse ; tout ce
/// qui se lit ligne à ligne vit derrière ce lien.
class TbSection extends StatelessWidget {
  final IconData icone;
  final String titre;
  final Color accent;
  final Widget child;

  /// Libellé et cible du lien d'en-tête (« Détail », « État de parc »…).
  /// Sans [onVoir], pas de lien.
  final String libelleVoir;
  final VoidCallback? onVoir;

  /// Pastille posée après le titre (ex. : nombre de points à traiter).
  final Widget? badge;

  TbSection({
    super.key,
    required this.icone,
    required this.titre,
    required this.child,
    Color? accent,
    this.libelleVoir = 'Voir tout',
    this.onVoir,
    this.badge,
  }) : accent = accent ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icone, size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(titre,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (badge != null) ...[const SizedBox(width: 8), badge!],
                  ],
                ),
              ),
              if (onVoir != null) TbLienVoir(libelle: libelleVoir, onTap: onVoir!),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Lien texte « Voir › » des en-têtes de section.
class TbLienVoir extends StatelessWidget {
  final String libelle;
  final VoidCallback onTap;

  const TbLienVoir({super.key, required this.libelle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 2, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(libelle,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

/// Carte en relief, dans le langage de la carte solde de l'accueil : filet
/// dégradé et fond teinté de l'accent. Réservée au premier regard de la page.
class TbCarteRelief extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const TbCarteRelief({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardBorderGradient,
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.cardInnerRadius),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardTint,
            borderRadius: BorderRadius.circular(AppColors.cardInnerRadius),
          ),
          padding: padding,
          child: child,
        ),
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
            style: TextStyle(fontSize: 12.5, color: AppColors.label)),
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
              style: TextStyle(fontSize: 11.5, color: AppColors.hint)),
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
/// Avec [onTap], elle devient un lien et le signale par un chevron.
class TbKpiTuile extends StatelessWidget {
  final String label;
  final String valeur;
  final Color couleur;
  final String? sousLabel;

  /// Explication affichée à l'appui long : la définition du ratio. Un
  /// indicateur qu'on ne sait pas définir ne sert à rien.
  final String? aide;

  final VoidCallback? onTap;

  TbKpiTuile({
    super.key,
    required this.label,
    required this.valeur,
    Color? couleur,
    this.sousLabel,
    this.aide,
    this.onTap,
  }) : couleur = couleur ?? kTbNeutre;

  @override
  Widget build(BuildContext context) {
    final contenu = Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 11.5, color: AppColors.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.hint),
            ],
          ),
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
                style: TextStyle(fontSize: 10.5, color: AppColors.hint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );

    final tuile = Material(
      color: AppColors.scaffold,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: contenu),
    );

    return tbAvecAide(aide, tuile);
  }
}

/// Enveloppe [enfant] d'une bulle d'aide à l'appui long, s'il y a une aide.
Widget tbAvecAide(String? aide, Widget enfant) {
  if (aide == null) return enfant;
  return Tooltip(
    message: aide,
    triggerMode: TooltipTriggerMode.longPress,
    showDuration: const Duration(seconds: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    // Couleurs du thème (bulle inversée) : un blanc forcé disparaissait sur la
    // bulle claire du mode sombre.
    textStyle: TextStyle(fontSize: 12, color: AppColors.scaffold),
    child: enfant,
  );
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

/// Jauge circulaire d'un taux : l'arc dit la proportion avant qu'on lise le
/// chiffre. Un taux absent (« — ») laisse l'anneau vide, sans couleur.
class TbJauge extends StatelessWidget {
  final double? taux;
  final Color couleur;
  final double taille;

  const TbJauge({
    super.key,
    required this.taux,
    required this.couleur,
    this.taille = 76,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille,
      height: taille,
      child: CustomPaint(
        painter: _JaugePainter(
          fraction: ((taux ?? 0) / 100).clamp(0.0, 1.0).toDouble(),
          couleur: couleur,
          piste: AppColors.border,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(tbPourcent(taux, decimales: 0),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: taux == null ? AppColors.hint : couleur)),
            ),
          ),
        ),
      ),
    );
  }
}

class _JaugePainter extends CustomPainter {
  final double fraction;
  final Color couleur;
  final Color piste;

  _JaugePainter(
      {required this.fraction, required this.couleur, required this.piste});

  @override
  void paint(Canvas canvas, Size size) {
    const epaisseur = 7.0;
    final rect = Rect.fromLTWH(epaisseur / 2, epaisseur / 2,
        size.width - epaisseur, size.height - epaisseur);
    final trait = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, trait..color = piste);
    if (fraction > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false,
          trait..color = couleur);
    }
  }

  @override
  bool shouldRepaint(_JaugePainter old) =>
      old.fraction != fraction || old.couleur != couleur || old.piste != piste;
}

/// Segment d'une [TbBarreSegments].
typedef TbSegment = ({String libelle, double valeur, String texte, Color couleur});

/// Barre segmentée avec sa légende : une répartition se lit en proportions,
/// pas en trois nombres côte à côte. Les segments nuls sont omis.
class TbBarreSegments extends StatelessWidget {
  final List<TbSegment> segments;

  const TbBarreSegments({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    final visibles = segments.where((s) => s.valeur > 0).toList();
    final total = visibles.fold<double>(0, (t, s) => t + s.valeur);
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            // Étirés en hauteur : un ColoredBox sans enfant prend sinon la
            // plus petite hauteur permise, zéro, et la barre disparaît.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visibles.length; i++) ...[
                  // Filet de surface entre deux aplats : sans lui, deux
                  // segments voisins se lisent comme un seul bloc.
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: (visibles[i].valeur / total * 1000)
                        .round()
                        .clamp(1, 1000),
                    child: ColoredBox(color: visibles[i].couleur),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final s in visibles)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: s.couleur,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 5),
                  Text('${s.libelle}  ',
                      style: TextStyle(fontSize: 11, color: AppColors.label)),
                  Text(s.texte,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Ligne cliquable : pastille d'icône, libellé et précision, valeur à droite,
/// chevron. Pour les listes courtes qui mènent chacune à une fiche (débiteur,
/// véhicule, point à traiter).
class TbLigneLien extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String libelle;
  final String? precision;
  final Color? couleurPrecision;
  final String valeur;
  final Color? couleurValeur;
  final VoidCallback? onTap;

  const TbLigneLien({
    super.key,
    required this.icone,
    required this.couleur,
    required this.libelle,
    this.precision,
    this.couleurPrecision,
    required this.valeur,
    this.couleurValeur,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, size: 18, color: couleur),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(libelle,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (precision != null)
                    Text(precision!,
                        style: TextStyle(
                            fontSize: 11,
                            color: couleurPrecision ?? AppColors.hint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(valeur,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: couleurValeur ?? AppColors.dark)),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.hint),
              ),
          ],
        ),
      ),
    );
  }
}

/// Barre de progression vers un seuil (point mort) : remplie jusqu'à 100 %,
/// verte une fois le seuil franchi.
class TbProgression extends StatelessWidget {
  final double? taux;
  final Color couleur;

  const TbProgression({super.key, required this.taux, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: ((taux ?? 0) / 100).clamp(0.0, 1.0).toDouble(),
        minHeight: 8,
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation(couleur),
      ),
    );
  }
}

/// Pastille de compteur posée après un titre de section.
class TbPastille extends StatelessWidget {
  final String texte;
  final Color couleur;

  const TbPastille({super.key, required this.texte, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(texte,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w800, color: couleur)),
    );
  }
}
