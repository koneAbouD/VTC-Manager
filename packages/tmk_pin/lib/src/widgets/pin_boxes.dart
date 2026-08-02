import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pin_theme.dart';

/// Les cases de saisie du code : une par chiffre, la suivante à remplir est
/// mise en évidence.
///
/// [errorTick] déclenche la secousse : incrémentez-le à chaque code refusé.
/// Ce signal plutôt qu'un booléen évite d'avoir à repasser par un état « pas
/// d'erreur » pour rejouer l'animation sur deux échecs consécutifs.
class PinBoxes extends StatefulWidget {
  final int length;
  final int filled;
  final int errorTick;
  final PinTheme theme;

  /// Taille d'une case sur un écran assez large. Cases et espacements sont
  /// réduits ensemble si la place manque (voir [build]).
  final double boxSize;
  final double spacing;

  const PinBoxes({
    super.key,
    required this.length,
    required this.filled,
    required this.theme,
    this.errorTick = 0,
    this.boxSize = 58,
    this.spacing = 14,
  });

  @override
  State<PinBoxes> createState() => _PinBoxesState();
}

class _PinBoxesState extends State<PinBoxes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(PinBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorTick != oldWidget.errorTick) {
      // La secousse se double d'un retour tactile : le refus se perçoit même
      // sans regarder l'écran.
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inError = _shake.isAnimating;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        // Oscillation amortie : quatre allers-retours qui s'éteignent.
        final offset = sin(_shake.value * pi * 8) * 10 * (1 - _shake.value);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Cinq cases de 58 dépassent d'un écran de 320 dp : plutôt que de
          // déborder, on rétrécit cases et espacements du même facteur.
          final ideale = widget.length * widget.boxSize +
              (widget.length - 1) * widget.spacing;
          final disponible = constraints.maxWidth;
          final facteur = disponible.isFinite && disponible < ideale
              ? disponible / ideale
              : 1.0;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) SizedBox(width: widget.spacing * facteur),
                _Box(
                  size: widget.boxSize * facteur,
                  filled: i < widget.filled,
                  active: i == widget.filled,
                  inError: inError,
                  theme: widget.theme,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final double size;
  final bool filled;
  final bool active;
  final bool inError;
  final PinTheme theme;

  const _Box({
    required this.size,
    required this.filled,
    required this.active,
    required this.inError,
    required this.theme,
  });

  static const _duration = Duration(milliseconds: 180);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final borderColor = inError
        ? theme.error
        : (active || filled ? theme.accent : theme.border);

    // La case en attente de frappe se détache légèrement : bordure accentuée,
    // halo coloré et infime agrandissement. L'œil sait où il en est sans
    // compter les cases.
    return AnimatedScale(
      duration: _duration,
      curve: _curve,
      scale: active && !inError ? 1.05 : 1,
      // Le côté est posé sec, hors de l'AnimatedContainer : quand la largeur
      // disponible change (rotation, redimensionnement), la case doit adopter
      // sa nouvelle taille au frame suivant. Animée, elle traînerait 180 ms à
      // l'ancienne — cinq cases trop larges, donc une rangée qui déborde le
      // temps de la transition. Seule la décoration s'anime.
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedContainer(
          duration: _duration,
          curve: _curve,
          decoration: BoxDecoration(
            color: filled ? theme.tintColor : theme.fillColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: active || filled ? 2 : 1.2,
            ),
            boxShadow: active && !inError
                ? [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: AnimatedScale(
            duration: _duration,
            curve: Curves.easeOutBack,
            scale: filled ? 1 : 0,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                color: inError ? theme.error : theme.filled,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
