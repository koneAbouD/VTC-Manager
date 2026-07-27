import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/responsive_field_row.dart'
    show kFormPhoneBreakpoint;
import '../../../auth/presentation/pages/pin_brand.dart';
import '../../../auth/presentation/pages/pin_setup_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../../jour_ferie/presentation/jours_feries_page.dart';
import '../widgets/settings_tile.dart';
import 'parametrage_hub_page.dart';
import 'parametres_generaux_page.dart';

/// Nom commercial et version, affichés au pied de page et dans « À propos ».
const _kAppName = 'DJULATCHE';
const _kAppVersion = '1.0.0';

/// Marges de la page et écart entre les cartes, alignés sur `rapports_tab` :
/// les cartes occupent toute la largeur disponible, sans contrainte.
const double _kPagePadding = 16;
const double _kCardGap = 10;

/// Arrondi du bas du bandeau de profil — même valeur que la barre de
/// navigation flottante de l'accueil.
const double _kHeaderRadius = 24;

/// Arrondi des pilules du bandeau, aligné sur les boutons d'[AppHeader].
const double _kPillRadius = 20;

/// Durée des transitions du bandeau (dépli, avatar, chevron). Assez lente pour
/// rester douce à l'œil, assez courte pour ne pas faire attendre.
const _kTransition = Duration(milliseconds: 240);

/// Première lettre en majuscule, le reste inchangé — sauf si la valeur est
/// entièrement capitalisée (« ABOU »), auquel cas elle repasse en casse
/// normale plutôt que de crier.
String _capitaliser(String valeur) {
  final v = valeur.trim();
  if (v.isEmpty) return v;
  final base = v == v.toUpperCase() ? v.toLowerCase() : v;
  return base[0].toUpperCase() + base.substring(1);
}

/// Identité du compte connecté, lue dans le jeton courant : il n'existe pas de
/// fiche utilisateur côté back-office, le jeton est la seule source.
typedef _IdentiteCompte = ({
  String nomComplet,
  String identifiant,
  String email,
});

final _identiteCompteProvider = FutureProvider<_IdentiteCompte>((ref) async {
  final token = await ref.watch(secureStorageProvider).getAccessToken();
  final claims = JwtClaims.parse(token);

  // Prénom + nom (`given_name` / `family_name`), présentés « Prénom NOM » ;
  // à défaut le `name` complet que Keycloak compose lui-même.
  final prenomNom = [
    _capitaliser(claims.givenName ?? ''),
    (claims.string('family_name') ?? '').toUpperCase(),
  ].where((part) => part.isNotEmpty).join(' ');

  final identifiant = claims.preferredUsername ?? '';
  final email = claims.string('email') ?? '';

  return (
    nomComplet:
        prenomNom.isNotEmpty ? prenomNom : (claims.string('name') ?? ''),
    identifiant: identifiant,
    // Beaucoup de comptes se connectent avec leur e-mail : on ne l'affiche
    // qu'une fois.
    email: email.toLowerCase() == identifiant.toLowerCase() ? '' : email,
  );
});

/// Volets dépliables de la page : un seul reste ouvert à la fois.
enum _Volet { profil, parametres, notifications, aide }

/// Page des réglages de l'application.
///
/// Les entrées sont regroupées par domaine (compte, configuration métier,
/// application) ; l'action sensible — la déconnexion — est isolée en bas.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Volet actuellement déplié, `null` si tout est replié. Ouvrir l'un referme
  /// donc l'autre, sans que les accordéons aient à se connaître.
  _Volet? _volet;

  void _basculer(_Volet volet) =>
      setState(() => _volet = _volet == volet ? null : volet);

  @override
  Widget build(BuildContext context) {
    // Descriptions réservées aux écrans larges ; les marges, elles, restent
    // les mêmes partout ([_kPagePadding] / [_kCardGap]).
    final isWide = MediaQuery.sizeOf(context).width >= kFormPhoneBreakpoint;

    final auth = ref.watch(authNotifierProvider);
    final identite = ref.watch(_identiteCompteProvider).valueOrNull;

    // Le jeton porte le nom complet ; l'état d'authentification (prénom seul)
    // prend le relais tant qu'il n'est pas lu, ou s'il ne le renseigne pas.
    final displayName = auth is AuthAuthenticated ? auth.displayName : '';
    final nomComplet = switch (identite?.nomComplet) {
      final String nom when nom.isNotEmpty => nom,
      _ => displayName,
    };

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      // Barre de retour et bandeau de profil partagent la même teinte : ils
      // forment une seule zone, arrondie en bas. Pas de titre : l'identité du
      // compte tient lieu d'en-tête.
      appBar: const AppHeader(
        title: '',
        backgroundColor: AppColors.headerButton,
        // Même pastille blanche que le bouton « Mon profil » : sans cela, le
        // fond du bouton se confondrait avec celui du bandeau.
        backButtonColor: AppColors.surface,
      ),
      body: LayoutBuilder(builder: (context, contraintes) {
        // Le bandeau n'est pas flexible : déplié sur un écran bas (paysage), il
        // réclamerait plus que la hauteur disponible et écraserait la liste. On
        // lui laisse au plus 60 % de la place, au-delà desquels il défile sur
        // lui-même.
        final hauteurMaxBandeau = contraintes.maxHeight * 0.6;

        return Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: hauteurMaxBandeau),
              child: SingleChildScrollView(
                child: _ProfileHeader(
                  name: nomComplet,
                  identifiant: identite?.identifiant ?? '',
                  email: identite?.email ?? '',
                  horizontalPadding: _kPagePadding,
                  avecDescriptions: isWide,
                  ouvert: _volet == _Volet.profil,
                  onToggle: () => _basculer(_Volet.profil),
                ),
              ),
            ),
            Expanded(
              // Padding bas incluant l'inset système pour que le pied de page ne
              // passe pas sous la barre de navigation Android.
              child: _CorpsDefilant(
                padding: EdgeInsets.fromLTRB(_kPagePadding, 8, _kPagePadding,
                    24 + MediaQuery.of(context).padding.bottom),
                pied: _PiedDePage(
                  onLogout: () {
                    Navigator.pop(context);
                    ref.read(authNotifierProvider.notifier).logout();
                  },
                ),
                children: [
                  SettingsAccordion(
                    icon: Icons.settings_outlined,
                    title: 'Paramètres',
                    ouvert: _volet == _Volet.parametres,
                    onToggle: () => _basculer(_Volet.parametres),
                    children: [
                      SettingsTile(
                        icon: Icons.flag_outlined,
                        title: 'Jours fériés',
                        description: 'Jours suspendant recettes et cotisations',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const JoursFeriesPage()),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.tune_rounded,
                        title: 'Données de référence',
                        description: 'Catégories, types, statuts et groupes',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ParametrageHubPage()),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.settings_suggest_outlined,
                        title: 'Paramétrage généraux',
                        description:
                            "Réglages globaux : durée d'amortissement…",
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ParametresGenerauxPage()),
                        ),
                      ),
                      // Les deux réglages suivants n'ont pas encore de
                      // mécanisme derrière eux : switch présent mais inerte
                      // (voir le rapport de livraison).
                      const SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        description: 'Alertes documents, entretiens et impayés',
                        trailing: Switch(value: false, onChanged: null),
                      ),
                      const SettingsTile(
                        icon: Icons.fingerprint_rounded,
                        title: 'Biométrie',
                        description:
                            "Déverrouiller l'application par empreinte ou "
                            'reconnaissance faciale',
                        trailing: Switch(value: false, onChanged: null),
                      ),
                      const SettingsTile(
                        icon: Icons.star_outline_rounded,
                        title: "Noter l'application",
                        description: 'Disponible à la publication sur les '
                            'stores',
                      ),
                      SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: 'À propos de nous',
                        onTap: () => _showAboutDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: _kCardGap),
                  SettingsAccordion(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    ouvert: _volet == _Volet.notifications,
                    onToggle: () => _basculer(_Volet.notifications),
                    children: const [
                      SettingsPlaceholder(
                        'Le centre de notifications arrive bientôt : '
                        'documents à renouveler, entretiens dus et impayés.',
                      ),
                    ],
                  ),
                  const SizedBox(height: _kCardGap),
                  SettingsAccordion(
                    icon: Icons.support_agent_rounded,
                    title: 'Aide et assistance',
                    ouvert: _volet == _Volet.aide,
                    onToggle: () => _basculer(_Volet.aide),
                    children: const [
                      SettingsPlaceholder(
                        "L'aide en ligne et le contact du support seront "
                        'disponibles bientôt.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('À propos'),
        content: const Text(
          '$_kAppName - Gestion de flotte VTC\n\n'
          'Version $_kAppVersion\n\n'
          '© 2026 $_kAppName',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'identité en haut de la page : avatar, nom du compte, identifiant
/// de connexion et accès au profil.
///
/// Prolonge l'[AppHeader] (même teinte) et se referme par des angles arrondis
/// en bas ; il occupe toute la largeur, son contenu restant aligné sur la
/// liste de réglages.
class _ProfileHeader extends StatelessWidget {
  /// Prénom et nom du compte connecté.
  final String name;

  /// Identifiant de connexion Keycloak — l'application ne dispose d'aucune
  /// fiche utilisateur, donc d'aucun numéro de téléphone.
  final String identifiant;

  /// Adresse e-mail du compte, si le jeton la porte et qu'elle ne fait pas
  /// double emploi avec l'identifiant.
  final String email;

  final double horizontalPadding;

  /// Descriptions sous les libellés des actions : réservées aux écrans larges,
  /// où la place ne manque pas.
  final bool avecDescriptions;

  /// Volet « Mon profil » déplié. Piloté par la page, qui n'en laisse ouvert
  /// qu'un seul.
  final bool ouvert;
  final VoidCallback onToggle;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.identifiant,
    required this.horizontalPadding,
    required this.avecDescriptions,
    required this.ouvert,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final libelle = name.trim().isEmpty ? 'Mon compte' : name.trim();
    final initiale = libelle.substring(0, 1).toUpperCase();

    // L'e-mail n'accompagne que le volet ouvert ; l'avatar s'agrandit alors
    // d'un cran pour rester à l'échelle du bloc d'identité.
    final emailVisible = ouvert && email.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.headerButton,
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(_kHeaderRadius)),
      ),
      // Mêmes marges latérales que la liste : l'avatar reste aligné sur les
      // icônes des cartes.
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 2, horizontalPadding, 18),
        child: Column(
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: _kTransition,
                  curve: Curves.easeOutCubic,
                  width: emailVisible ? 62 : 52,
                  height: emailVisible ? 62 : 52,
                  alignment: Alignment.center,
                  // Même pastille blanche que le bouton « Mon profil ».
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: _kTransition,
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: emailVisible ? 24 : 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                    child: Text(initiale),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        libelle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (identifiant.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          identifiant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.label,
                          ),
                        ),
                      ],
                      // Apparition et disparition en douceur, au rythme
                      // du volet.
                      AnimatedSize(
                        duration: _kTransition,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topLeft,
                        child: emailVisible
                            ? Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.hint,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _MonProfilBouton(ouvert: ouvert, onTap: onToggle),
              ],
            ),
            // Repli/dépli des actions de compte.
            AnimatedSize(
              duration: _kTransition,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: ouvert
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _ActionsProfil(
                        avecDescriptions: avecDescriptions,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Actions de compte révélées par « Mon profil », une par ligne.
///
/// Reprend les briques de la liste de réglages ([SettingsCard] /
/// [SettingsTile]) : icône à gauche, chevron à droite, même carte blanche.
class _ActionsProfil extends StatelessWidget {
  final bool avecDescriptions;

  const _ActionsProfil({required this.avecDescriptions});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      children: [
        // Aucune fiche utilisateur n'existe côté back-office : l'entrée est
        // affichée en retrait, comme « Notifications » et « Aide & support ».
        SettingsTile(
          icon: Icons.person_outline_rounded,
          title: 'Mes informations personnelles',
          description: avecDescriptions
              ? 'Nom, identifiant de connexion et adresse e-mail'
              : null,
          trailing:
              const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
        ),
        SettingsTile(
          icon: Icons.dialpad_rounded,
          title: 'Modifier mon code',
          description: avecDescriptions
              ? 'Remplacer le code à ${PinService.codeLength} chiffres '
                  'd\'ouverture'
              : null,
          // Le code est toujours installé (il conditionne l'ouverture de
          // l'application) : on va droit au changement, en exigeant le code
          // actuel, sans passer par un écran de réglages intermédiaire.
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PinSetupPage(
                requireCurrentCode: true,
                onDone: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bouton « Mon profil » : déplie et replie les actions de compte.
class _MonProfilBouton extends StatelessWidget {
  final bool ouvert;
  final VoidCallback onTap;

  const _MonProfilBouton({required this.ouvert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(_kPillRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kPillRadius),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mon profil',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(width: 4),
              // Chevron vers le bas quand le volet est replié, vers le haut
              // une fois ouvert.
              AnimatedRotation(
                turns: ouvert ? -0.25 : 0.25,
                duration: _kTransition,
                curve: Curves.easeOutCubic,
                child: const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.dark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pied de page : identité de l'application, mentions légales et sortie de
/// session — la seule action irréversible de l'écran, isolée tout en bas.
class _PiedDePage extends StatelessWidget {
  final VoidCallback onLogout;

  const _PiedDePage({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Le logo est une image carrée à fond blanc : on adoucit ses angles
        // pour l'accorder aux cartes de la page.
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: const PinBrand(height: 34),
        ),
        const SizedBox(height: 10),
        const Text(
          'Version $_kAppVersion',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.label,
          ),
        ),
        const SizedBox(height: 8),
        // Wrap plutôt que Row : sur un écran étroit, la seconde mention passe
        // à la ligne au lieu de déborder.
        const Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            _MentionLegale('Conditions Générales'),
            Text('|', style: TextStyle(fontSize: 12, color: AppColors.border)),
            _MentionLegale('Avis de Confidentialité'),
          ],
        ),
        const SizedBox(height: 20),
        _BoutonDeconnexion(onTap: onLogout),
      ],
    );
  }
}

/// Mention légale du pied de page.
///
/// Présentée en retrait et non cliquable : les documents ne sont pas encore
/// publiés, il n'y a rien à ouvrir.
class _MentionLegale extends StatelessWidget {
  final String libelle;

  const _MentionLegale(this.libelle);

  @override
  Widget build(BuildContext context) {
    return Text(
      libelle,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.hint,
      ),
    );
  }
}

/// Sortie de session : pilule sobre, texte et icône en rouge — le code couleur
/// des actions sensibles de l'application.
class _BoutonDeconnexion extends StatelessWidget {
  final VoidCallback onTap;

  const _BoutonDeconnexion({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_kPillRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_kPillRadius),
          child: Container(
            height: 48,
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kPillRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                SizedBox(width: 10),
                // Flexible : le libellé se resserre plutôt que de déborder
                // quand l'utilisateur agrandit la taille du texte système.
                Flexible(
                  child: Text(
                    'Se déconnecter',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Libellé en noir comme les autres boutons de la page ;
                    // seule l'icône garde le rouge de l'action sensible.
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Corps de la page : les cartes défilent, le pied de page reste collé au bas
/// de l'écran tant que le contenu ne remplit pas la hauteur disponible.
class _CorpsDefilant extends StatelessWidget {
  final List<Widget> children;
  final Widget pied;
  final EdgeInsets padding;

  const _CorpsDefilant({
    required this.children,
    required this.pied,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            // Hauteur minimale = la zone visible : la colonne occupe alors tout
            // l'écran et son `spaceBetween` pousse le pied vers le bas. Dès que
            // le contenu dépasse, la colonne reprend sa hauteur naturelle et
            // tout défile normalement. Le plancher à zéro couvre le cas où les
            // marges à elles seules dépassent la place restante.
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - padding.vertical)
                  .clamp(0.0, double.infinity),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(children: children),
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: pied,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
