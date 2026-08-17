import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Onglets d'un hub en pastilles flottantes, posées dans l'en-tête de page
/// (slot `center` d'[AppHeader]) plutôt que dans le corps de l'écran.
///
/// La pastille active se détache en blanc, texte vert ; les autres restent sur
/// le gris des boutons d'en-tête. Tant que les libellés tiennent sur la ligne,
/// la rangée est centrée et l'espace qui sépare les pastilles suit la largeur
/// de l'écran ; au-delà (hub à cinq onglets), elle défile horizontalement et
/// ramène d'elle-même l'onglet actif sous les yeux.
class HeaderTabsPills extends StatefulWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelected;

  const HeaderTabsPills({
    super.key,
    required this.labels,
    required this.index,
    required this.onSelected,
  });

  @override
  State<HeaderTabsPills> createState() => _HeaderTabsPillsState();
}

class _HeaderTabsPillsState extends State<HeaderTabsPills> {
  final _scroll = ScrollController();
  late List<GlobalKey> _cles = _nouvellesCles();

  List<GlobalKey> _nouvellesCles() =>
      List.generate(widget.labels.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(HeaderTabsPills ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.labels.length != widget.labels.length) {
      _cles = _nouvellesCles();
    }
    if (ancien.index != widget.index) _revelerOngletActif();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Ramène la pastille active dans le champ de vision — utile quand la
  /// sélection vient d'ailleurs (raccourci d'un autre écran) plutôt que d'un tap.
  void _revelerOngletActif() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final contexte = _cles[widget.index].currentContext;
      if (contexte == null) return;
      Scrollable.ensureVisible(
        contexte,
        alignment: 0.5,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  /// Largeur d'une pastille, texte au plus gras (celui de l'onglet actif) :
  /// la rangée ne doit pas changer de mode en changeant d'onglet. Le style
  /// hérité est repris tel quel — sans lui, la mesure et le rendu peuvent
  /// diverger de quelques pixels et faire déborder la rangée.
  double _largeurPastille(String label, TextScaler echelle) {
    final style = DefaultTextStyle.of(context)
        .style
        .merge(_Pill.styleTexte(actif: true));
    final peintre = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: echelle,
    )..layout();
    return peintre.width +
        _Pill.paddingHorizontal * 2 +
        _Pill.bordure * 2 +
        _margeMesure;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final echelle = MediaQuery.textScalerOf(context);
        final largeurs =
            widget.labels.map((l) => _largeurPastille(l, echelle)).toList();
        final cumul = largeurs.fold<double>(0, (a, b) => a + b);
        final intervalles = widget.labels.length - 1;

        final dispo =
            contraintes.hasBoundedWidth ? contraintes.maxWidth : double.infinity;
        // L'écart se sert en premier : proportionnel à la largeur offerte, dans
        // des bornes qui gardent la rangée aérée du petit téléphone à la
        // tablette. Les pastilles se partagent ensuite ce qui reste.
        final ecartCible =
            dispo.isFinite ? (dispo * 0.07).clamp(_ecartCibleMinimum, 32.0) : 16.0;
        final laPlusLarge = largeurs.reduce((a, b) => a > b ? a : b);
        final partPastille =
            (dispo - ecartCible * intervalles) / widget.labels.length;

        // Cas nominal : la rangée remplit la ligne, pastilles toutes de même
        // largeur — au moins celle du plus long libellé — séparées de l'écart
        // voulu. Sinon on resserre l'écart sur les largeurs propres à chaque
        // libellé, et en dernier recours la rangée défile.
        final etirable = dispo.isFinite && partPastille >= laPlusLarge;
        final naturelTient = dispo >= cumul + _ecartMinimum * intervalles;
        final tientSurLaLigne = intervalles == 0 || etirable || naturelTient;

        final largeurPastille = etirable ? partPastille : null;
        final ecart = switch ((etirable, tientSurLaLigne, intervalles)) {
          (_, _, 0) => 0.0,
          (true, _, _) => ecartCible,
          (false, true, _) =>
            ((dispo - cumul) / intervalles).clamp(_ecartMinimum, ecartCible),
          _ => _ecartMinimum,
        };

        Widget pastille(int i) => KeyedSubtree(
              key: _cles[i],
              child: _Pill(
                label: widget.labels[i],
                actif: i == widget.index,
                largeur: largeurPastille,
                onTap: () => widget.onSelected(i),
              ),
            );

        if (tientSurLaLigne) {
          // Chaque pastille est flexible : si la mesure ci-dessus s'écarte d'un
          // cheveu du rendu (moteur web, police de repli), la rangée se resserre
          // au lieu de déborder de l'en-tête. Sans largeur bornée, en revanche,
          // un enfant flexible n'a rien à quoi se rapporter : la rangée reste
          // alors rigide (il n'y a de toute façon aucune place à disputer).
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.labels.length; i++) ...[
                if (i > 0) SizedBox(width: ecart),
                if (dispo.isFinite) Flexible(child: pastille(i)) else pastille(i),
              ],
            ],
          );
        }

        // Trop de libellés pour la ligne : la rangée défile, sans jamais
        // rogner un libellé ni déborder de l'en-tête. Pas de `Flexible` ici,
        // la largeur offerte au défilement étant illimitée.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _scroll,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.labels.length; i++) ...[
                if (i > 0) SizedBox(width: ecart),
                pastille(i),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Écart incompressible entre deux pastilles, quand la place vient à manquer.
const double _ecartMinimum = 8;

/// Plancher de l'écart visé tant que la rangée tient sur la ligne.
const double _ecartCibleMinimum = 14;

/// Marge ajoutée à chaque largeur mesurée : le rendu réel peut dépasser le
/// calcul du [TextPainter] d'une fraction de pixel par pastille.
const double _margeMesure = 2;

class _Pill extends StatelessWidget {
  final String label;
  final bool actif;
  final VoidCallback onTap;

  /// Largeur imposée, commune à toute la rangée ; null = au plus juste.
  final double? largeur;

  const _Pill({
    required this.label,
    required this.actif,
    required this.onTap,
    this.largeur,
  });

  // Rembourrage minimal du libellé : la largeur réelle vient de la rangée, qui
  // étire les pastilles sur la place laissée par les écarts.
  static const double paddingHorizontal = 10;
  static const double bordure = 0.8;

  static TextStyle styleTexte({required bool actif}) => TextStyle(
        fontSize: 12,
        fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
        color: actif ? AppColors.primary : AppColors.label,
        letterSpacing: -0.1,
      );

  @override
  Widget build(BuildContext context) {
    // La largeur est imposée du dehors, jamais animée : elle passe d'une valeur
    // fixe à « au plus juste » quand la rangée change de régime (fenêtre
    // redimensionnée), et une animation ne sait pas relier ces deux mondes.
    final pastille = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: paddingHorizontal),
      decoration: BoxDecoration(
        // Onglet actif en blanc franc, les autres sur le gris des boutons
        // d'en-tête : ils restent en relief tout en passant au second plan.
        color: actif ? AppColors.surface : AppColors.headerButton,
        borderRadius: BorderRadius.circular(17),
        // Bordure transparente sur l'onglet actif : la pastille garde la
        // même largeur d'un état à l'autre, sans saut de mise en page.
        border: Border.all(
          color: actif ? Colors.transparent : AppColors.border,
          width: bordure,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: actif ? 0.06 : 0.03),
            blurRadius: actif ? 6 : 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 180),
        style: styleTexte(actif: actif),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: largeur == null
          ? pastille
          : SizedBox(width: largeur, child: pastille),
    );
  }
}
