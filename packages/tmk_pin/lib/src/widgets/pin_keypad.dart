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

  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.theme,
    this.enabled = true,
    this.maxWidth = 320,
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
                    onTap: enabled ? () => _press(digit) : null,
                    child: _DigitLabel(digit: digit, color: theme.digit),
                  ),
              ]),
            _Row(children: [
              const _Key(onTap: null, child: SizedBox.shrink()),
              _Key(
                onTap: enabled ? () => _press('0') : null,
                child: _DigitLabel(digit: '0', color: theme.digit),
              ),
              _Key(
                onTap: enabled ? _erase : null,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 28,
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

class _Key extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _Key({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.5,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 48,
          containedInkWell: false,
          child: Center(child: child),
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
          fontSize: 32,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      );
}
