import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pin_theme.dart';

/// Pavé numérique de l'écran de code.
///
/// Clavier dédié plutôt que clavier système : la saisie reste à l'écran sans
/// recouvrir la mise en page, les touches sont grandes, et rien ne transite
/// par un clavier tiers (suggestions, presse-papiers, saisie prédictive).
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Grise le pavé pendant une vérification ou une temporisation.
  final bool enabled;

  final PinTheme theme;
  final double maxWidth;

  /// Touche facultative en bas à gauche — le déverrouillage biométrique, à la
  /// place que lui donnent iOS et Android. Sans elle, l'emplacement reste vide.
  final PinAuxKey? auxKey;

  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.theme,
    this.enabled = true,
    this.maxWidth = 320,
    this.auxKey,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              _Row(children: [
                for (final digit in row)
                  _Key(
                    theme: theme,
                    onTap: enabled ? () => _press(digit) : null,
                    semanticsLabel: digit,
                    child: _DigitLabel(digit: digit, color: theme.digit),
                  ),
              ]),
            _Row(children: [
              if (auxKey == null)
                _Key(theme: theme, onTap: null, child: const SizedBox.shrink())
              else
                _Key(
                  // Pas de pastille : comme l'effacement, la touche est
                  // secondaire, l'œil doit aller d'abord aux chiffres.
                  theme: theme,
                  filled: false,
                  onTap: enabled ? () => _presserAux(auxKey!) : null,
                  semanticsLabel: auxKey!.label,
                  child: Icon(auxKey!.icon, size: 30, color: theme.accent),
                ),
              _Key(
                theme: theme,
                onTap: enabled ? () => _press('0') : null,
                semanticsLabel: '0',
                child: _DigitLabel(digit: '0', color: theme.digit),
              ),
              _Key(
                // Pas de pastille sous l'effacement : la touche reste
                // secondaire, l'œil va d'abord aux chiffres.
                theme: theme,
                filled: false,
                onTap: enabled ? _erase : null,
                semanticsLabel: 'Effacer',
                child: Icon(
                  Icons.backspace_rounded,
                  size: 26,
                  color: theme.digit,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _press(String digit) {
    HapticFeedback.selectionClick();
    onDigit(digit);
  }

  void _erase() {
    HapticFeedback.selectionClick();
    onBackspace();
  }

  void _presserAux(PinAuxKey key) {
    HapticFeedback.selectionClick();
    key.onTap();
  }
}

/// Touche auxiliaire du pavé (bas à gauche) : une icône, un libellé
/// d'accessibilité, une action.
@immutable
class PinAuxKey {
  final IconData icon;

  /// Lu par les lecteurs d'écran (« Déverrouiller avec Face ID »).
  final String label;

  final VoidCallback onTap;

  const PinAuxKey({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _Row extends StatelessWidget {
  final List<Widget> children;
  const _Row({required this.children});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [for (final child in children) Expanded(child: child)],
      );
}

/// Touche du pavé : pastille ronde qui s'enfonce légèrement sous le doigt.
class _Key extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final PinTheme theme;

  /// Pastille de fond — absente pour la touche d'effacement.
  final bool filled;

  final String? semanticsLabel;

  const _Key({
    required this.onTap,
    required this.child,
    required this.theme,
    this.filled = true,
    this.semanticsLabel,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final actif = widget.onTap != null;

    return AspectRatio(
      aspectRatio: 1.5,
      child: Semantics(
        button: actif,
        label: widget.semanticsLabel,
        excludeSemantics: widget.semanticsLabel != null,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Pastille inscrite dans la case : ronde et généreuse, sans
              // jamais déborder sur un écran étroit.
              final diametre =
                  min(constraints.maxWidth, constraints.maxHeight) * 0.92;

              return AnimatedScale(
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOut,
                scale: _pressed ? 0.92 : 1,
                child: SizedBox(
                  width: diametre,
                  height: diametre,
                  child: Material(
                    color: widget.filled && actif
                        ? widget.theme.fillColor
                        : Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkResponse(
                      onTap: widget.onTap,
                      onTapDown: actif ? (_) => _setPressed(true) : null,
                      onTapUp: actif ? (_) => _setPressed(false) : null,
                      onTapCancel: actif ? () => _setPressed(false) : null,
                      radius: diametre,
                      highlightColor:
                          widget.theme.accent.withValues(alpha: 0.08),
                      splashColor: widget.theme.accent.withValues(alpha: 0.14),
                      child: Center(child: widget.child),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DigitLabel extends StatelessWidget {
  final String digit;
  final Color color;

  const _DigitLabel({required this.digit, required this.color});

  @override
  Widget build(BuildContext context) => Text(
        digit,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1,
        ),
      );
}
