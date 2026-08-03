import 'dart:async';

import 'package:flutter/material.dart';

/// Bandeau affiché *dans* l'application quand une notification arrive alors que
/// l'utilisateur l'a sous les yeux.
///
/// Android n'affiche rien de lui-même dans ce cas, et il a raison : une
/// bannière système par-dessus l'écran qu'on est en train de lire serait
/// intrusive. Reste que l'événement a bien eu lieu — sans ce bandeau, un
/// versement enregistré ou une pénalité passerait inaperçu jusqu'à la prochaine
/// visite du centre de notifications.
///
/// Le texte vient de la notification, déjà sobre par construction : ni montant,
/// ni nom, ni immatriculation. Rien n'est donc exposé ici qui ne le serait déjà
/// sur l'écran verrouillé — à une réserve près, qui appartient à l'appelant :
/// ne pas l'afficher par-dessus l'écran du code d'accès.
///
/// Une seule bannière à la fois. Un second message remplace le premier plutôt
/// que de s'empiler dessus : deux notifications arrivées ensemble décrivent
/// presque toujours le même fait, et l'utilisateur retrouvera les deux dans son
/// centre de notifications.
void afficherBannierePush(
  OverlayState overlay, {
  required String titre,
  required String corps,
  required IconData icone,
  required Color accent,
  VoidCallback? onTap,
  Duration duree = const Duration(seconds: 5),
}) {
  _BanniereCourante.remplacer(
    overlay,
    titre: titre,
    corps: corps,
    icone: icone,
    accent: accent,
    onTap: onTap,
    duree: duree,
  );
}

/// Retire la bannière visible, s'il y en a une. À appeler lorsque l'application
/// se remet sous clé : le bandeau ne doit pas survivre au verrouillage.
void masquerBannierePush() => _BanniereCourante.retirer();

/// L'unique entrée d'overlay en cours d'affichage.
///
/// L'état est volontairement global : il n'y a qu'un seul overlay racine et une
/// seule bannière visible à la fois, quel que soit l'écran affiché.
class _BanniereCourante {
  static OverlayEntry? _entree;

  static void remplacer(
    OverlayState overlay, {
    required String titre,
    required String corps,
    required IconData icone,
    required Color accent,
    required VoidCallback? onTap,
    required Duration duree,
  }) {
    retirer();

    late final OverlayEntry entree;
    entree = OverlayEntry(
      builder: (_) => _Banniere(
        titre: titre,
        corps: corps,
        icone: icone,
        accent: accent,
        duree: duree,
        onTap: onTap,
        // Ne retire que si elle est encore la bannière courante : une bannière
        // remplacée pendant qu'elle s'efface a déjà été retirée, et une entrée
        // d'overlay ne se retire pas deux fois.
        onFin: () {
          if (!identical(_entree, entree)) return;
          _entree = null;
          entree.remove();
        },
      ),
    );

    _entree = entree;
    overlay.insert(entree);
  }

  static void retirer() {
    _entree?.remove();
    _entree = null;
  }
}

class _Banniere extends StatefulWidget {
  final String titre;
  final String corps;
  final IconData icone;
  final Color accent;
  final Duration duree;
  final VoidCallback? onTap;
  final VoidCallback onFin;

  const _Banniere({
    required this.titre,
    required this.corps,
    required this.icone,
    required this.accent,
    required this.duree,
    required this.onTap,
    required this.onFin,
  });

  @override
  State<_Banniere> createState() => _BanniereState();
}

class _BanniereState extends State<_Banniere> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  Timer? _minuterie;

  /// Empêche la double sortie : le doigt et la minuterie peuvent arriver
  /// ensemble, et retirer deux fois la même entrée d'overlay lève.
  bool _sortie = false;

  @override
  void initState() {
    super.initState();
    _animation.forward();
    _minuterie = Timer(widget.duree, _fermer);
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    _animation.dispose();
    super.dispose();
  }

  Future<void> _fermer() async {
    if (_sortie) return;
    _sortie = true;
    _minuterie?.cancel();
    if (!mounted) return;

    // Le retrait attend la fin de l'animation de sortie. Si la bannière a
    // disparu entre temps — remplacée, ou emportée par un verrouillage — c'est
    // que quelqu'un d'autre a déjà retiré l'entrée.
    await _animation.reverse();
    if (mounted) widget.onFin();
  }

  void _toucher() {
    final action = widget.onTap;
    _fermer();
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: _animation,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                color: surface,
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _toucher,
                  // Balayage vers le haut : le geste qu'on fait naturellement
                  // pour chasser une bannière système.
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < 0) _fermer();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: widget.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(widget.icone, size: 19, color: widget.accent),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.titre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (widget.corps.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.corps,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
