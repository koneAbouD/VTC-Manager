import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Briques d'interface de la page Paramètres.
///
/// Même langage visuel que les cartes de `parametrage_hub_page` et de
/// `detail_premium` : surface blanche, bordure fine, coins arrondis et icône
/// teintée — seuls les en-têtes d'accordéon posent l'icône sur une pastille.

/// Rayon des cartes de réglages.
const double _kCardRadius = 16;

/// Décalage du filet séparateur : padding gauche + colonne d'icône +
/// gouttière, pour que le trait démarre sous le libellé et non sous l'icône.
const double _kDividerIndent = 70;

/// Durée des transitions de la page (dépli des accordéons, rotation des
/// chevrons) : assez lente pour rester douce, assez courte pour ne pas faire
/// attendre.
const kSettingsTransition = Duration(milliseconds: 240);

/// Intercale un filet fin entre chaque ligne d'une carte.
List<Widget> _separees(List<Widget> lignes) {
  final resultat = <Widget>[];
  for (var i = 0; i < lignes.length; i++) {
    if (i > 0) {
      resultat.add(const Divider(
        height: 1,
        thickness: 1,
        indent: _kDividerIndent,
        endIndent: 14,
        color: AppColors.border,
      ));
    }
    resultat.add(lignes[i]);
  }
  return resultat;
}

/// Enveloppe commune des cartes de réglages : surface blanche, bordure fine,
/// coins arrondis et clip (pour que l'effet d'appui suive les arrondis).
class _CarteReglages extends StatelessWidget {
  final Widget child;

  const _CarteReglages({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: child,
      ),
    );
  }
}

/// Carte accueillant une ou plusieurs [SettingsTile], séparées par un filet.
///
/// S'utilise seule, sans en-tête (ex. : déconnexion, actions du profil).
class SettingsCard extends StatelessWidget {
  final List<Widget> children;

  /// Pose les lignes à même le fond qui les accueille : ni surface propre ni
  /// bordure, seuls les filets les séparent. Utile quand la carte est déjà
  /// contenue dans un bloc coloré — une seconde surface y ferait boîte dans
  /// la boîte.
  final bool sansFond;

  const SettingsCard({
    super.key,
    required this.children,
    this.sansFond = false,
  });

  @override
  Widget build(BuildContext context) {
    final contenu = Column(children: _separees(children));
    return sansFond ? contenu : _CarteReglages(child: contenu);
  }
}

/// Carte dépliante : un en-tête distinctif qui révèle ses [children] — des
/// [SettingsTile] — quand [ouvert] passe à vrai.
///
/// L'ouverture est pilotée par le parent ([ouvert] / [onToggle]) : la page peut
/// ainsi n'en laisser qu'une seule dépliée à la fois.
///
/// **Hiérarchie visuelle** : une fois déplié, l'en-tête se teinte, sa pastille
/// d'icône devient pleine et son titre passe à la couleur de marque, tandis que
/// les lignes filles gardent le fond blanc, une icône nue et un léger retrait.
/// Parent et enfants ne se confondent jamais.
class SettingsAccordion extends StatelessWidget {
  final IconData icon;
  final String title;

  /// Sous-titre de l'en-tête, quand il apporte quelque chose.
  final String? description;

  final List<Widget> children;

  /// Teinte de l'en-tête et des pastilles.
  final Color accent;

  final bool ouvert;
  final VoidCallback onToggle;

  const SettingsAccordion({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    required this.ouvert,
    required this.onToggle,
    this.description,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return _CarteReglages(
      child: Column(
        children: [
          _EnteteAccordion(
            icon: icon,
            title: title,
            description: description,
            accent: accent,
            ouvert: ouvert,
            onTap: onToggle,
          ),
          AnimatedSize(
            duration: kSettingsTransition,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: ouvert
                ? Column(
                    children: [
                      // Frontière nette entre l'en-tête et ce qu'il contient.
                      const Divider(
                          height: 1, thickness: 1, color: AppColors.border),
                      // Retrait des lignes filles : la hiérarchie se lit d'un
                      // coup d'œil, sans surcharge.
                      Padding(
                        padding:
                            const EdgeInsets.only(left: kSettingsChildIndent),
                        child: Column(children: _separees(children)),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Retrait horizontal des lignes filles d'un accordéon déplié.
///
/// Partagé pour que toute liste de [SettingsTile] posée hors accordéon — les
/// actions du bandeau de profil, par exemple — s'aligne sur celles des volets.
const double kSettingsChildIndent = 8;

/// En-tête d'un [SettingsAccordion] : pastille pleine et titre coloré une fois
/// déplié, retour au repos sinon. Toutes les bascules sont animées.
class _EnteteAccordion extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Color accent;
  final bool ouvert;
  final VoidCallback onTap;

  const _EnteteAccordion({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.ouvert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: kSettingsTransition,
          curve: Curves.easeOutCubic,
          color: ouvert ? AppColors.primaryTint : AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              AnimatedContainer(
                duration: kSettingsTransition,
                curve: Curves.easeOutCubic,
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ouvert ? accent : accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: ouvert ? AppColors.surface : accent),
                  duration: kSettingsTransition,
                  curve: Curves.easeOutCubic,
                  builder: (_, couleur, __) =>
                      Icon(icon, size: 20, color: couleur),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: kSettingsTransition,
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: ouvert ? 15.5 : 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: ouvert ? 0.1 : 0,
                        color: ouvert ? AppColors.primaryDark : AppColors.dark,
                      ),
                      child: Text(title),
                    ),
                    if (description != null && description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: AppColors.label,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: ouvert ? -0.25 : 0.25,
                duration: kSettingsTransition,
                curve: Curves.easeOutCubic,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                      end: ouvert ? AppColors.primaryDark : AppColors.hint),
                  duration: kSettingsTransition,
                  curve: Curves.easeOutCubic,
                  builder: (_, couleur, __) =>
                      Icon(Icons.chevron_right_rounded, color: couleur),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Facteur d'échelle des interrupteurs de la page.
///
/// Un [Switch] Material pèse lourd à côté d'une icône de 20 px : réduit, il
/// s'accorde au reste de la ligne sans dominer le libellé. Un peu moins serré
/// que les bascules des pages de référentiel : la ligne est ici plus haute.
const double _kSwitchScale = 0.78;

/// Interrupteur d'une [SettingsTile], à l'échelle de la ligne.
///
/// [Transform.scale] emporte la zone tactile avec lui ; la ligne entière reste
/// cliquable via `onTap`, on ne perd donc rien à viser un peu plus petit.
class SettingsSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: _kSwitchScale,
      child: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        // Sans cela, le Switch réserve 48 px de haut : la ligne s'étirerait
        // alors que l'interrupteur, lui, a rapetissé.
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Ligne d'information sans action, pour un contenu d'accordéon encore vide.
class SettingsPlaceholder extends StatelessWidget {
  final String message;

  const SettingsPlaceholder(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 18, color: AppColors.hint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.3,
                color: AppColors.label,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de réglage : icône, libellé (+ description optionnelle) et élément de
/// droite.
///
/// - [onTap] non nul → la ligne est interactive ; un chevron est affiché quand
///   aucun [trailing] n'est fourni (le réglage ouvre une page).
/// - [onTap] nul → la ligne est présentée en retrait (non tactile) ; c'est le
///   cas des entrées annoncées mais pas encore disponibles.
/// - [trailing] accueille tout élément de droite : pastille d'information,
///   compteur, ou [Switch] le jour où un réglage booléen apparaîtra.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Teinte de l'icône.
  final Color accent;

  /// Couleur du libellé — à surcharger pour les actions sensibles
  /// (déconnexion : [AppColors.error]).
  final Color? titleColor;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.onTap,
    this.trailing,
    this.accent = AppColors.primary,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final labelColor =
        titleColor ?? (enabled ? AppColors.dark : AppColors.hint);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          // Icône nue, sans pastille : seul l'en-tête d'accordéon porte un
          // fond coloré. La boîte garde ses 42 px pour que libellés et filets
          // séparateurs restent alignés sur ceux de l'en-tête.
          SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 20,
              color: enabled ? accent : AppColors.hint,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: AppColors.label,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (trailing != null)
            trailing!
          else if (enabled)
            const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
        ],
      ),
    );

    if (!enabled) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
