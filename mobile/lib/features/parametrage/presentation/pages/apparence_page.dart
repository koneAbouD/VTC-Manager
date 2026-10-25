import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/detail_premium.dart';

/// Libellé court d'un mode d'éclairage, pour le sélecteur comme pour le
/// résumé affiché dans les réglages.
String libelleModeTheme(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Clair',
      ThemeMode.dark => 'Sombre',
      ThemeMode.system => 'Système',
    };

/// Durée des bascules de la page (segment actif, pastille choisie).
const _kTransition = Duration(milliseconds: 220);

/// Réglages › Configurations › Apparence : mode clair / sombre / système et
/// couleur d'accent.
///
/// Le choix s'applique à l'instant — sans bouton « Enregistrer » — et reste
/// mémorisé sur l'appareil. L'aperçu est posé en tête : sur un téléphone, il
/// reste sous les yeux pendant qu'on choisit, au lieu de fuir sous le pli.
class ApparencePage extends ConsumerWidget {
  const ApparencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apparence = ref.watch(themeControllerProvider);
    final controleur = ref.read(themeControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Apparence'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          _CarteApercu(apparence: apparence),
          const SizedBox(height: 16),
          PremiumSection(
            title: "Mode d'affichage",
            icon: Icons.contrast_rounded,
            children: [
              const SizedBox(height: 4),
              _SelecteurMode(
                valeur: apparence.mode,
                onChanged: (mode) {
                  HapticFeedback.selectionClick();
                  controleur.choisirMode(mode);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
                child: Text(
                  apparence.mode == ThemeMode.system
                      ? "L'application suit le réglage de votre téléphone, "
                          'même quand il bascule en cours de journée.'
                      : 'Système : suit le réglage de votre téléphone.',
                  style: TextStyle(
                      fontSize: 12, height: 1.35, color: AppColors.label),
                ),
              ),
            ],
          ),
          PremiumSection(
            title: "Couleur d'accent",
            icon: Icons.palette_outlined,
            children: [
              const SizedBox(height: 6),
              _GrilleAccents(
                valeur: apparence.accent,
                onChanged: (accent) {
                  HapticFeedback.selectionClick();
                  controleur.choisirAccent(accent);
                },
              ),
            ],
          ),
          // Rien à rétablir tant que rien n'a été changé.
          if (!apparence.estParDefaut)
            PremiumButton(
              label: "Rétablir l'apparence d'origine",
              icon: Icons.restart_alt_rounded,
              filled: false,
              color: AppColors.label,
              onPressed: () {
                HapticFeedback.lightImpact();
                controleur.reinitialiser();
              },
            ),
        ],
      ),
    );
  }
}

/// Carte en relief (même filet dégradé que le solde de l'accueil) : résumé du
/// choix et maquette des éléments courants — montant, puce de statut, lignes
/// de détail, bouton — pour juger du résultat d'un coup d'œil.
class _CarteApercu extends StatelessWidget {
  final ThemeSettings apparence;

  const _CarteApercu({required this.apparence});

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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aperçu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                  PremiumChip(
                    '${libelleModeTheme(apparence.mode)} · '
                    '${apparence.accent.libelle}',
                    AppColors.primary,
                    icon: AppColors.estSombre
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Fausse fiche de recette, construite avec les mêmes briques que
              // les vraies pages de détail.
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_taxi_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Recette du jour',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.label,
                            ),
                          ),
                        ),
                        PremiumChip('Encaissé', AppColors.positive,
                            icon: Icons.check_circle_rounded),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '45 000 FCFA',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const PremiumRow('Véhicule', 'AB-123-CD'),
                    PremiumRow('Reste dû', '5 000 FCFA',
                        valueColor: AppColors.warning),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PremiumButton(
                label: 'Encaisser',
                icon: Icons.payments_outlined,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contrôle segmenté : rail grisé, segment actif détaché en surface claire,
/// icône et libellé à la couleur d'accent.
class _SelecteurMode extends StatelessWidget {
  final ThemeMode valeur;
  final ValueChanged<ThemeMode> onChanged;

  const _SelecteurMode({required this.valeur, required this.onChanged});

  /// Ordre d'affichage : du plus clair au plus « automatique ».
  static const _ordre = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

  static const _icones = {
    ThemeMode.light: Icons.light_mode_rounded,
    ThemeMode.dark: Icons.dark_mode_rounded,
    ThemeMode.system: Icons.brightness_auto_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final mode in _ordre)
            Expanded(
              child: _Segment(
                libelle: libelleModeTheme(mode),
                icone: _icones[mode]!,
                selectionne: mode == valeur,
                onTap: () => onChanged(mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String libelle;
  final IconData icone;
  final bool selectionne;
  final VoidCallback onTap;

  const _Segment({
    required this.libelle,
    required this.icone,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = selectionne ? AppColors.primary : AppColors.label;
    return Semantics(
      button: true,
      selected: selectionne,
      label: 'Mode $libelle',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: _kTransition,
          curve: Curves.easeOutCubic,
          // 56 px : la cible tactile reste confortable au pouce.
          height: 56,
          decoration: BoxDecoration(
            color: selectionne ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selectionne
                ? [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: AppColors.estSombre ? 0.4 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 20, color: couleur),
              const SizedBox(height: 3),
              Text(
                libelle,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selectionne ? FontWeight.w800 : FontWeight.w600,
                  color: couleur,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastilles de couleur, quatre par ligne. La couleur affichée est celle du
/// mode en cours : ce qu'on voit est ce qu'on obtient.
class _GrilleAccents extends StatelessWidget {
  final AppAccent valeur;
  final ValueChanged<AppAccent> onChanged;

  const _GrilleAccents({required this.valeur, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const colonnes = 4;
      final largeur = c.maxWidth / colonnes;
      return Wrap(
        children: [
          for (final accent in AppAccent.values)
            SizedBox(
              width: largeur,
              child: _Pastille(
                accent: accent,
                selectionne: accent == valeur,
                onTap: () => onChanged(accent),
              ),
            ),
        ],
      );
    });
  }
}

class _Pastille extends StatelessWidget {
  final AppAccent accent;
  final bool selectionne;
  final VoidCallback onTap;

  const _Pastille({
    required this.accent,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = AppColors.estSombre ? accent.primaryNuit : accent.primary;
    return Semantics(
      button: true,
      selected: selectionne,
      label: 'Accent ${accent.libelle}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Column(
            children: [
              // Anneau à la couleur de l'accent, détaché de la pastille par un
              // liseré de la couleur du fond : la sélection se lit sans
              // recouvrir la teinte.
              AnimatedContainer(
                duration: _kTransition,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectionne ? couleur : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: AnimatedScale(
                  duration: _kTransition,
                  curve: Curves.easeOutBack,
                  scale: selectionne ? 1 : 0.9,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: couleur,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: couleur.withValues(alpha: 0.35),
                          blurRadius: selectionne ? 10 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: _kTransition,
                      transitionBuilder: (enfant, anim) =>
                          ScaleTransition(scale: anim, child: enfant),
                      child: selectionne
                          ? const Icon(Icons.check_rounded,
                              key: ValueKey('coche'),
                              color: Colors.white,
                              size: 22)
                          : const SizedBox.shrink(key: ValueKey('vide')),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                accent.libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selectionne ? FontWeight.w800 : FontWeight.w600,
                  color: selectionne ? AppColors.dark : AppColors.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
