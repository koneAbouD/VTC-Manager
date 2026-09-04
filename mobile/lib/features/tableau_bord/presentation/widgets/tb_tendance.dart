import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/tableau_bord_model.dart';
import 'tb_briques.dart';

/// Courbe de tendance : le résultat mensuel des douze derniers mois, en barres.
///
/// **Pourquoi des barres et pas une courbe** : la grandeur portée ici change de
/// signe. Une ligne qui traverse le zéro se lit comme une pente ; des barres
/// ancrées au zéro se lisent comme une alternance de mois gagnés et de mois
/// perdus — ce qui est la question posée. Une seule série, donc pas de légende :
/// le titre la nomme.
///
/// **Une seule échelle** : produits et charges partagent l'unité du résultat,
/// mais les superposer sur un second axe donnerait deux échelles dans un même
/// cadre — la première erreur de lecture d'un tableau de bord. On montre donc
/// le résultat seul, et le mois touché révèle son détail sous le graphe.
class TbTendance extends StatefulWidget {
  final List<PointSerie> serie;

  /// Mois affiché en cadrage du tableau de bord : mis en évidence dans la
  /// série, car c'est celui que commentent tous les autres blocs.
  final int annee;
  final int mois;

  const TbTendance({
    super.key,
    required this.serie,
    required this.annee,
    required this.mois,
  });

  @override
  State<TbTendance> createState() => _TbTendanceState();
}

class _TbTendanceState extends State<TbTendance> {
  /// Barre touchée, ou null : le détail retombe alors sur le mois cadré.
  int? _selection;

  int get _indexCadre => widget.serie.indexWhere(
      (p) => p.annee == widget.annee && p.mois == widget.mois);

  @override
  Widget build(BuildContext context) {
    if (widget.serie.isEmpty) return const SizedBox.shrink();

    final indexDetail = _selection ?? (_indexCadre >= 0 ? _indexCadre : widget.serie.length - 1);
    final point = widget.serie[indexDetail];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text('Résultat mensuel — 12 mois glissants',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label)),
            ),
            Text('EBE, base caisse',
                style: TextStyle(fontSize: 10.5, color: AppColors.hint)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: LayoutBuilder(builder: (context, contraintes) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _selectionner(d.localPosition.dx, contraintes.maxWidth),
              onHorizontalDragUpdate: (d) =>
                  _selectionner(d.localPosition.dx, contraintes.maxWidth),
              onHorizontalDragEnd: (_) => setState(() => _selection = null),
              child: CustomPaint(
                size: Size(contraintes.maxWidth, 112),
                painter: _TendancePainter(
                  serie: widget.serie,
                  indexMisEnAvant: indexDetail,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        _DetailPoint(point: point),
      ],
    );
  }

  void _selectionner(double dx, double largeur) {
    final pas = largeur / widget.serie.length;
    final index = (dx / pas).floor().clamp(0, widget.serie.length - 1);
    if (index != _selection) setState(() => _selection = index);
  }
}

/// Lecture chiffrée du mois touché : le graphe donne la forme, cette ligne
/// donne les valeurs — sans écrire un nombre sur chaque barre.
class _DetailPoint extends StatelessWidget {
  final PointSerie point;
  const _DetailPoint({required this.point});

  @override
  Widget build(BuildContext context) {
    final libelleMois =
        '${point.label[0].toUpperCase()}${point.label.substring(1)} ${point.annee}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      // Le mois au-dessus, les trois mesures réparties en colonnes égales :
      // sur une seule ligne, trois montants longs débordent d'un téléphone.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(libelleMois,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                  child: _Mesure(
                      label: 'Produits',
                      valeur: point.produits,
                      couleur: AppColors.dark)),
              Expanded(
                  child: _Mesure(
                      label: 'Charges',
                      valeur: point.charges,
                      couleur: AppColors.dark)),
              Expanded(
                  child: _Mesure(
                      label: 'Résultat',
                      valeur: point.resultat,
                      couleur: tbCouleurMontant(point.resultat))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mesure extends StatelessWidget {
  final String label;
  final double valeur;
  final Color couleur;

  const _Mesure(
      {required this.label, required this.valeur, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 9.5, color: AppColors.hint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(tbMontantCourt(valeur),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: couleur)),
        ),
      ],
    );
  }
}

/// Dessine les barres autour de l'axe zéro.
class _TendancePainter extends CustomPainter {
  final List<PointSerie> serie;
  final int indexMisEnAvant;

  /// Écart entre deux barres, en pixels de surface : deux aplats collés se
  /// lisent comme un seul.
  static const double _gouttiere = 4;

  /// Rayon des extrémités de barre.
  static const Radius _rayon = Radius.circular(4);

  _TendancePainter({required this.serie, required this.indexMisEnAvant});

  @override
  void paint(Canvas canvas, Size size) {
    if (serie.isEmpty) return;

    const double hauteurLabels = 16;
    final hauteurPlot = size.height - hauteurLabels;

    final valeurs = serie.map((p) => p.resultat).toList();
    final maxAbs = valeurs.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
    // Aucune valeur : on trace l'axe seul plutôt qu'un graphe faux.
    final echelle = maxAbs == 0 ? 1.0 : maxAbs;

    // Position du zéro : centré quand la série change de signe, posé au bas du
    // cadre quand tout est positif — sinon la moitié du graphe resterait vide.
    final aDuNegatif = valeurs.any((v) => v < 0);
    final yZero = aDuNegatif ? hauteurPlot * 0.55 : hauteurPlot - 2;
    final hautDisponible = yZero - 2;
    final basDisponible = hauteurPlot - yZero - 2;

    final axe = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, yZero), Offset(size.width, yZero), axe);

    final pas = size.width / serie.length;
    final largeurBarre = (pas - _gouttiere).clamp(3.0, 22.0);

    for (var i = 0; i < serie.length; i++) {
      final valeur = serie[i].resultat;
      final positif = valeur >= 0;
      final ratio = (valeur.abs() / echelle).clamp(0.0, 1.0);
      final hauteur = ratio * (positif ? hautDisponible : basDisponible);

      final x = i * pas + (pas - largeurBarre) / 2;
      final rect = positif
          ? Rect.fromLTWH(x, yZero - hauteur, largeurBarre, hauteur)
          : Rect.fromLTWH(x, yZero, largeurBarre, hauteur);

      final enAvant = i == indexMisEnAvant;
      final couleur = valeur == 0
          ? AppColors.border
          : (positif ? kTbVert : kTbRouge);
      final peinture = Paint()
        ..color = enAvant ? couleur : couleur.withValues(alpha: 0.35);

      // Extrémité libre arrondie, extrémité ancrée au zéro laissée droite :
      // la barre reste visiblement posée sur son axe.
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: positif ? _rayon : Radius.zero,
          topRight: positif ? _rayon : Radius.zero,
          bottomLeft: positif ? Radius.zero : _rayon,
          bottomRight: positif ? Radius.zero : _rayon,
        ),
        peinture,
      );

      // Étiquettes de mois : une sur trois, plus celle du mois mis en avant.
      // Douze libellés collés seraient illisibles sur un téléphone.
      final derniere = i == serie.length - 1;
      if (enAvant || i % 3 == 0 || derniere) {
        _texte(canvas, serie[i].label, x + largeurBarre / 2,
            hauteurPlot + 3, enAvant, size.width);
      }
    }
  }

  void _texte(Canvas canvas, String texte, double cx, double y, bool enAvant,
      double largeurMax) {
    final peintre = TextPainter(
      text: TextSpan(
        text: texte,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: enAvant ? FontWeight.w700 : FontWeight.w400,
          color: enAvant ? AppColors.dark : AppColors.hint,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = (cx - peintre.width / 2).clamp(0.0, largeurMax - peintre.width);
    peintre.paint(canvas, Offset(dx, y));
  }

  @override
  bool shouldRepaint(_TendancePainter old) =>
      old.serie != serie || old.indexMisEnAvant != indexMisEnAvant;
}
