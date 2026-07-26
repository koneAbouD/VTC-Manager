import 'package:flutter/material.dart';

import 'pin_boxes.dart';
import 'pin_keypad.dart';
import 'pin_theme.dart';

/// Mise en page commune aux écrans de code : marque en haut, cases de saisie
/// au milieu, pavé numérique en bas.
///
/// Les deux applications et les deux écrans (déverrouillage et création) la
/// partagent ; seuls les textes, le logo et l'action de pied de page changent.
class PinLayout extends StatelessWidget {
  /// Logo de l'application (déjà dimensionné par l'appelant).
  final Widget? brand;

  /// Titre au-dessus de la consigne. Absent sur l'écran de verrouillage.
  final String? title;
  final String prompt;

  /// Message d'erreur ou d'avertissement sous les cases (essais restants,
  /// temporisation…). Occupe une hauteur fixe pour que le pavé ne saute pas.
  final String? message;

  /// Action en haut à droite — la déconnexion sur l'écran de verrouillage.
  final Widget? action;

  /// Lien de pied de page (« Code TMK oublié ? », « Plus tard »).
  final Widget? footer;

  final int length;
  final int filled;
  final int errorTick;
  final bool busy;
  final PinTheme theme;

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const PinLayout({
    super.key,
    required this.prompt,
    required this.length,
    required this.filled,
    required this.theme,
    required this.onDigit,
    required this.onBackspace,
    this.brand,
    this.title,
    this.message,
    this.action,
    this.footer,
    this.errorTick = 0,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: action ?? const SizedBox.shrink(),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (brand != null) ...[
                    const SizedBox(height: 12),
                    brand!,
                  ],
                  SizedBox(height: title == null ? 40 : 20),
                  if (title != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        title!,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          color: theme.digit,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  Text(
                    prompt,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(color: theme.digit),
                  ),
                  const SizedBox(height: 16),
                  // La marge laisse respirer les cases sur écran étroit et
                  // donne de la place à la secousse d'erreur.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PinBoxes(
                      length: length,
                      filled: filled,
                      errorTick: errorTick,
                      theme: theme,
                    ),
                  ),
                  // Hauteur réservée : le pavé ne bouge pas quand un message
                  // apparaît ou disparaît.
                  SizedBox(
                    height: 44,
                    child: Center(
                      child: busy
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.accent,
                              ),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                message ?? '',
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(
                                  color: theme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          PinKeypad(
            onDigit: onDigit,
            onBackspace: onBackspace,
            theme: theme,
            enabled: !busy,
          ),
          SizedBox(
            height: 56,
            child: Center(child: footer ?? const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }
}
