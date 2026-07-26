import 'dart:math';

import 'package:flutter/material.dart';

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
        final offset =
            sin(_shake.value * pi * 8) * 10 * (1 - _shake.value);
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

  @override
  Widget build(BuildContext context) {
    final borderColor = inError
        ? theme.error
        : (active || filled ? theme.accent : theme.border);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: active || filled ? 2 : 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: filled ? 1 : 0,
        child: Container(
          width: size * 0.24,
          height: size * 0.24,
          decoration: BoxDecoration(
            color: inError ? theme.error : theme.filled,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
