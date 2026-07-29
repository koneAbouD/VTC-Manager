import 'package:flutter/material.dart';

import 'pin_boxes.dart';
import 'pin_keypad.dart';
import 'pin_theme.dart';

/// Mise en page commune aux écrans de code : marque en haut, cases de saisie
/// au milieu, pavé numérique en bas.
///
/// Les deux applications et les trois écrans (déverrouillage, création,
/// reprise) la partagent ; seuls les textes, le logo et l'action de pied de
/// page changent.
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

  /// Widget en haut à gauche — le retour, quand l'écran est ouvert depuis les
  /// réglages. Contrairement à [action], il est posé tel quel : c'est à
  /// l'application de lui donner l'allure de ses en-têtes.
  final Widget? leading;

  /// Lien de pied de page (« Code TMK oublié ? », « Plus tard »).
  final Widget? footer;

  final int length;
  final int filled;
  final int errorTick;
  final bool busy;
  final PinTheme theme;

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Touche facultative en bas à gauche du pavé — le déverrouillage
  /// biométrique sur l'écran de verrouillage, quand l'appareil le permet.
  final PinAuxKey? auxKey;

  /// Espace au-dessus du logo. L'écran de verrouillage, qui n'a pas de titre,
  /// le majore pour descendre le bloc de saisie vers le centre de l'écran.
  final double topSpacing;

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
    this.leading,
    this.footer,
    this.auxKey,
    this.errorTick = 0,
    this.busy = false,
    this.topSpacing = 12,
  });

  /// Zone réservée sous les cases : le pavé ne bouge pas selon qu'un message
  /// s'affiche ou non.
  static const _messageHeight = 48.0;

  /// Hauteurs des bandes fixes (barre d'action en haut, lien de pied de page).
  static const _actionHeight = 48.0;
  static const _footerHeight = 56.0;

  /// En dessous de cette hauteur, l'écran passe en deux colonnes : saisie à
  /// gauche, pavé à droite. C'est le cas du paysage sur téléphone, où empiler
  /// les quatre rangées de touches ne tient pas.
  static const _hauteurBasculeColonnes = 560.0;

  /// Largeur maximale du pavé.
  static const _largeurPaveMax = 320.0;

  /// Le pavé est une grille 3 × 4 de touches au format 1,5 : sa hauteur vaut
  /// donc 8/9 de sa largeur. On l'inverse pour tenir dans la place restante
  /// plutôt que de déborder.
  static double _largeurPavePourHauteur(double hauteurDisponible) =>
      (hauteurDisponible * 9 / 8).clamp(180.0, _largeurPaveMax);

  @override
  Widget build(BuildContext context) {
    // Dégradé à peine perceptible : il pose une profondeur sous le haut de
    // l'écran sans introduire de couleur étrangère à la charte.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.fillColor.withValues(alpha: 0.35),
            theme.fillColor.withValues(alpha: 0),
          ],
          stops: const [0, 0.45],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hauteur = constraints.maxHeight;
            final enColonnes = hauteur < _hauteurBasculeColonnes &&
                constraints.maxWidth > hauteur;
            return enColonnes ? _deuxColonnes(hauteur) : _empile(hauteur);
          },
        ),
      ),
    );
  }

  /// Disposition habituelle : saisie au-dessus, pavé puis pied de page en bas.
  Widget _empile(double hauteur) {
    // Le pavé cède du terrain avant que quoi que ce soit ne déborde : on lui
    // laisse la place restante une fois les bandes fixes et un bloc de saisie
    // minimal réservés.
    final largeurPave = _largeurPavePourHauteur(
        hauteur - _actionHeight - _footerHeight - _messageHeight - 110);

    return Column(
      children: [
        _barreAction(),
        Expanded(child: SingleChildScrollView(child: _saisie())),
        _pave(largeurPave),
        _piedDePage(),
      ],
    );
  }

  /// Paysage : saisie à gauche, pavé et pied de page à droite. Le pavé est
  /// dimensionné par la hauteur, jamais par la largeur disponible.
  Widget _deuxColonnes(double hauteur) {
    final largeurPave =
        _largeurPavePourHauteur(hauteur - _actionHeight - _footerHeight);

    return Column(
      children: [
        _barreAction(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SingleChildScrollView(child: _saisie()),
              ),
              SizedBox(
                width: largeurPave,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: _pave(largeurPave)),
                    _piedDePage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _barreAction() => SizedBox(
        height: _actionHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (leading != null) leading!,
              const Spacer(),
              if (action != null)
                // Bouton rond sur fond doux, comme les actions d'en-tête du
                // reste de l'application.
                Material(
                  color: theme.fillColor,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: action,
                ),
            ],
          ),
        ),
      );

  Widget _pave(double largeurMax) => PinKeypad(
        onDigit: onDigit,
        onBackspace: onBackspace,
        theme: theme,
        enabled: !busy,
        maxWidth: largeurMax,
        auxKey: auxKey,
      );

  Widget _piedDePage() => SizedBox(
        height: _footerHeight,
        child: Center(child: footer ?? const SizedBox.shrink()),
      );

  /// Marque, titre, consigne, cases et message : le bloc d'identification.
  Widget _saisie() => Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          return Column(
            children: [
              SizedBox(height: topSpacing),
              if (brand != null) brand!,
              SizedBox(height: title == null ? 40 : 20),
              if (title != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    title!,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: theme.digit,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  prompt,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.digit.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // La marge laisse respirer les cases sur écran étroit et donne
              // de la place à la secousse d'erreur.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PinBoxes(
                  length: length,
                  filled: filled,
                  errorTick: errorTick,
                  theme: theme,
                ),
              ),
              SizedBox(
                height: _messageHeight,
                child: Center(
                  child: _Feedback(theme: theme, busy: busy, message: message),
                ),
              ),
            ],
          );
        },
      );
}

/// Attente ou message, à la même place et sans saut de mise en page.
class _Feedback extends StatelessWidget {
  final PinTheme theme;
  final bool busy;
  final String? message;

  const _Feedback({required this.theme, required this.busy, this.message});

  @override
  Widget build(BuildContext context) {
    final Widget contenu;
    if (busy) {
      contenu = SizedBox(
        key: const ValueKey('busy'),
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: theme.accent),
      );
    } else if (message != null && message!.isNotEmpty) {
      // Pastille plutôt que texte nu : le refus se lit d'un coup d'œil,
      // sans crier.
      contenu = Container(
        key: ValueKey(message),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: theme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: theme.error),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.error,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      contenu = const SizedBox.shrink(key: ValueKey('vide'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      // Glissement plutôt que SizeTransition : cette dernière, en axe vertical,
      // occupe toute la largeur et plaque son enfant à gauche — le loader s'en
      // retrouvait décentré.
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: contenu,
    );
  }
}
