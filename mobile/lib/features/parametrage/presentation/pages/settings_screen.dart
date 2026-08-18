import 'dart:math' as math;

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
import '../../../condition_travail/presentation/pages/condition_travail_liste_page.dart';
import '../../../jour_ferie/presentation/jours_feries_page.dart';
import '../../../notification/presentation/pages/notifications_page.dart';
import '../../../notification/presentation/providers/notification_providers.dart';
import '../../../partenaire/presentation/pages/partenaires_liste_page.dart';
import '../../../profil/presentation/pages/mon_profil_page.dart';
import '../../../profil/presentation/providers/profil_providers.dart';
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

/// Volets dépliables de la page : un seul reste ouvert à la fois.
enum _Volet { profil, parametres, configurations, notifications, aide }

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

    // Deux sources pour la même identité : la fiche du référentiel, à jour dès
    // qu'elle a été modifiée, et le jeton — immédiat et disponible hors ligne.
    // Le jeton reste en retard d'une modification jusqu'à son renouvellement,
    // d'où la préférence donnée à la fiche quand elle a répondu.
    final fiche = ref.watch(monProfilProvider).valueOrNull;
    final identite = fiche == null
        ? ref.watch(identiteCompteProvider).valueOrNull
        : composerIdentite(
            prenom: fiche.prenom,
            nom: fiche.nom,
            identifiant: fiche.identifiant,
            email: fiche.email,
          );

    // Le jeton porte le nom complet ; l'état d'authentification (prénom seul)
    // prend le relais tant qu'il n'est pas lu, ou s'il ne le renseigne pas.
    final displayName = auth is AuthAuthenticated ? auth.displayName : '';
    final nomComplet = switch (identite?.nomComplet) {
      final String nom when nom.isNotEmpty => nom,
      _ => displayName,
    };

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      // Pas d'`appBar` : la barre de retour est intégrée au bandeau de profil,
      // qui descend du haut de l'écran d'un seul tenant. La teinte du bandeau
      // court donc de la barre de statut jusqu'au bas de l'identité, sans
      // rupture. Pas de titre non plus : l'identité du compte tient lieu
      // d'en-tête.
      body: LayoutBuilder(builder: (context, contraintes) {
        // Le bandeau n'est pas flexible : déplié sur un écran bas (paysage), il
        // réclamerait plus que la hauteur disponible et écraserait la liste. On
        // lui laisse au plus 60 % de la place, au-delà desquels il défile sur
        // lui-même.
        final hauteurMaxBandeau = contraintes.maxHeight * 0.6;

        return Column(
          children: [
            _ProfileHeader(
              name: nomComplet,
              identifiant: identite?.identifiant ?? '',
              email: identite?.email ?? '',
              horizontalPadding: _kPagePadding,
              avecDescriptions: isWide,
              ouvert: _volet == _Volet.profil,
              onToggle: () => _basculer(_Volet.profil),
              hauteurMaxIdentite: hauteurMaxBandeau,
            ),
            Expanded(
              // Le bandeau se termine par sa poignée : la première carte prend
              // ses distances pour que le trait garde son air. Padding bas
              // incluant l'inset système pour que le pied de page ne passe pas
              // sous la barre de navigation Android.
              child: _CorpsDefilant(
                padding: EdgeInsets.fromLTRB(_kPagePadding, 18, _kPagePadding,
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
                        icon: Icons.assignment_outlined,
                        title: 'Conditions de travail',
                        description:
                            'Programmes de recette, cotisations et pénalités',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ConditionTravailListePage()),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.flag_outlined,
                        title: 'Jours fériés',
                        description: 'Jours à recette spécifique',
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
                      // Le référentiel des partenaires vit ici, avec les
                      // autres données de référence : l'échéancier des dettes
                      // ne fait que s'en servir, il ne l'administre pas.
                      SettingsTile(
                        icon: Icons.store_outlined,
                        title: 'Partenaires',
                        description: 'Garagistes, assureurs et autres '
                            'prestataires',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const PartenairesListePage()),
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.settings_suggest_outlined,
                        title: 'Paramètres généraux',
                        description: 'Amortissement, provisions sur créances…',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ParametresGenerauxPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _kCardGap),
                  // Réglages de l'application elle-même — par opposition aux
                  // « Paramètres », qui portent les données métier.
                  SettingsAccordion(
                    icon: Icons.app_settings_alt_outlined,
                    title: 'Configurations',
                    ouvert: _volet == _Volet.configurations,
                    onToggle: () => _basculer(_Volet.configurations),
                    children: [
                      const _LigneNotifications(),
                      const _LigneBiometrie(),
                      // Même situation que les notifications : l'entrée est
                      // annoncée, le suivi de position n'est pas encore branché.
                      const SettingsTile(
                        icon: Icons.location_on_outlined,
                        title: 'Géolocalisation',
                        description: 'Suivi de position des chauffeurs en '
                            'service',
                        trailing: SettingsSwitch(value: false),
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
                    children: [
                      SettingsTile(
                        icon: Icons.inbox_rounded,
                        title: 'Centre de notifications',
                        description: 'Alertes reçues, lues et non lues',
                        trailing: _BadgeNonLues(ref.watch(nonLuesProvider)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NotificationsPage(),
                          ),
                        ),
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

/// Bandeau d'identité en haut de la page : barre de retour, avatar, nom du
/// compte, identifiant de connexion et accès au profil.
///
/// Bloc plein, posé depuis le haut de l'écran : la barre de retour baigne dans
/// la même teinte ([AppColors.headerButton]) que l'identité, ils forment une
/// seule zone dont seul le bord bas est arrondi. Il occupe toute la largeur,
/// son contenu restant aligné sur la liste de réglages.
class _ProfileHeader extends StatefulWidget {
  /// Prénom et nom du compte connecté.
  final String name;

  /// Identifiant de connexion Keycloak. Le bandeau s'en tient au strict
  /// nécessaire : le reste de la fiche vit dans « Mes informations
  /// personnelles ».
  final String identifiant;

  /// Adresse e-mail du compte, si elle est connue et qu'elle ne fait pas
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

  /// Hauteur maximale de la partie identité — barre de retour exclue, celle-ci
  /// restant visible en toutes circonstances. Au-delà, l'identité défile sur
  /// elle-même plutôt que d'écraser la liste de réglages.
  final double hauteurMaxIdentite;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.identifiant,
    required this.horizontalPadding,
    required this.avecDescriptions,
    required this.ouvert,
    required this.onToggle,
    required this.hauteurMaxIdentite,
  });

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader>
    with SingleTickerProviderStateMixin {
  /// Avancement du dépli, de 0 (replié) à 1 (déplié). Continu : glisser la
  /// poignée le déplace au rythme du doigt, le reste du temps il est animé
  /// d'une position à l'autre.
  late final AnimationController _depli = AnimationController(
    vsync: this,
    duration: _kTransition,
    value: widget.ouvert ? 1 : 0,
  );

  /// Posée sur le bloc d'actions : sa hauteur convertit les pixels parcourus
  /// par le doigt en fraction d'ouverture.
  final _contenuKey = GlobalKey();

  @override
  void didUpdateWidget(covariant _ProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La page reste maîtresse de l'état — elle ne laisse qu'un volet ouvert à
    // la fois : le bandeau ne fait que rejoindre la position demandée, depuis
    // là où le doigt l'a laissé.
    if (widget.ouvert != oldWidget.ouvert) _rejoindre(widget.ouvert);
  }

  @override
  void dispose() {
    _depli.dispose();
    super.dispose();
  }

  void _rejoindre(bool ouvert) =>
      _depli.animateTo(ouvert ? 1 : 0, curve: Curves.easeOutCubic);

  /// Course complète du dépli, en pixels. Vaut 1 tant que le bloc n'a pas été
  /// mesuré, pour ne jamais diviser par zéro.
  double get _course {
    final boite = _contenuKey.currentContext?.findRenderObject() as RenderBox?;
    final hauteur = boite?.size.height ?? 0;
    return hauteur > 0 ? hauteur : 1;
  }

  /// Vers le bas on ouvre, vers le haut on referme : la carte descend du haut
  /// de l'écran, c'est l'inverse d'une feuille modale.
  void _glisser(DragUpdateDetails details) =>
      _depli.value = (_depli.value + details.delta.dy / _course).clamp(0.0, 1.0);

  void _relacher(DragEndDetails details) {
    // Un geste franc l'emporte sur la distance parcourue : on suit sa
    // direction. Sinon c'est la moitié de la course qui tranche.
    final vitesse = details.velocity.pixelsPerSecond.dy;
    final ouvrir = vitesse.abs() > 300 ? vitesse > 0 : _depli.value >= 0.5;
    if (ouvrir == widget.ouvert) {
      _rejoindre(ouvrir); // état inchangé : le volet se recale seul
    } else {
      widget.onToggle(); // la page bascule, `didUpdateWidget` fait le reste
    }
  }

  @override
  Widget build(BuildContext context) {
    final libelle =
        widget.name.trim().isEmpty ? 'Mon compte' : widget.name.trim();
    final initiale = libelle.substring(0, 1).toUpperCase();

    return Container(
      width: double.infinity,
      // Le bloc part du haut de l'écran : il n'a pas de bord haut, seuls les
      // angles bas sont arrondis.
      decoration: const BoxDecoration(
        color: AppColors.headerButton,
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(_kHeaderRadius)),
      ),
      child: Column(children: [
        // Barre de retour posée sur la teinte du bandeau : le fond court sans
        // rupture depuis la barre de statut. Même pastille blanche que le
        // bouton « Mon profil » : sans cela, le fond du bouton se confondrait
        // avec celui du bandeau.
        const AppHeader(
          title: '',
          backgroundColor: Colors.transparent,
          backButtonColor: AppColors.surface,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.hauteurMaxIdentite),
          child: SingleChildScrollView(
            child: Padding(
              // L'en-tête pose déjà 14 px sous le bouton retour : l'identité
              // n'ajoute qu'un souffle avant l'avatar. En bas, c'est la
              // poignée qui tient lieu de marge.
              padding: EdgeInsets.fromLTRB(
                  widget.horizontalPadding, 2, widget.horizontalPadding, 0),
              child: AnimatedBuilder(
                animation: _depli,
                builder: (context, _) => _identite(libelle, initiale),
              ),
            ),
          ),
        ),
        _PoigneeDepli(
          onTap: widget.onToggle,
          onDragUpdate: _glisser,
          onDragEnd: _relacher,
        ),
      ]),
    );
  }

  /// Bloc d'identité rendu à l'avancement courant : l'avatar grandit, l'e-mail
  /// se déroule et les actions se découvrent d'un même mouvement.
  Widget _identite(String libelle, String initiale) {
    final t = _depli.value;
    // L'e-mail n'accompagne que le volet déplié, et seulement s'il apporte
    // quelque chose (cf. [composerIdentite]) ; l'avatar, qui s'agrandit
    // d'un cran pour rester à l'échelle du bloc, suit son sort.
    final tEmail = widget.email.isEmpty ? 0.0 : t;

    return Column(
      children: [
        // Tout le bloc d'identité déplie le volet, pas seulement la pilule
        // « Mon profil » : c'est la carte entière que l'on vise du pouce. Le
        // bouton garde son propre `onTap`, qui l'emporte sur celui-ci.
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                Container(
                  width: 52 + 10 * tEmail,
                  height: 52 + 10 * tEmail,
                  alignment: Alignment.center,
                  // Même pastille blanche que le bouton « Mon profil ».
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initiale,
                    style: TextStyle(
                      fontSize: 20 + 4 * tEmail,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
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
                      if (widget.identifiant.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.identifiant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.label,
                          ),
                        ),
                      ],
                      if (widget.email.isNotEmpty)
                        _decouvrir(
                          tEmail,
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.hint,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _MonProfilBouton(avancement: t, onTap: widget.onToggle),
              ],
            ),
          ),
        ),
        // Actions de compte, découvertes de haut en bas.
        _decouvrir(
          t,
          child: Padding(
            key: _contenuKey,
            // Même retrait que les lignes filles d'un accordéon : icônes et
            // libellés du profil tombent sur la même verticale que ceux des
            // volets de la liste.
            padding:
                const EdgeInsets.only(top: 14, left: kSettingsChildIndent),
            child: _ActionsProfil(avecDescriptions: widget.avecDescriptions),
          ),
        ),
      ],
    );
  }

  /// Laisse voir [child] à hauteur de [avancement] (0 → rien, 1 → tout), sans
  /// jamais le redimensionner : il se découvre par le haut, comme une feuille
  /// que l'on tire.
  static Widget _decouvrir(
    double avancement, {
    required Widget child,
    Alignment alignment = Alignment.topCenter,
  }) {
    return ClipRect(
      child: Align(
        alignment: alignment,
        heightFactor: avancement,
        child: Opacity(opacity: avancement, child: child),
      ),
    );
  }
}

/// Poignée du bandeau de profil : le petit trait centré en bordure basse.
///
/// Même trait que les feuilles modales de l'application, mais dans l'autre
/// sens : la carte descend du haut de l'écran, on la tire donc vers le bas
/// pour l'ouvrir et vers le haut pour la refermer. Un appui simple bascule,
/// comme un tap sur la poignée d'une feuille la referme.
class _PoigneeDepli extends StatelessWidget {
  final VoidCallback onTap;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;

  const _PoigneeDepli({
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Container(
        width: double.infinity,
        // Zone de préhension bien plus large que le trait : c'est tout le bas
        // du bandeau qui répond au pouce. Elle tient aussi lieu de marge sous
        // l'identité.
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            // Un cran plus soutenu que [AppColors.border] : le bandeau est
            // lui-même gris clair, le trait s'y perdrait.
            color: AppColors.hint.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Réglage du déverrouillage biométrique.
///
/// La ligne s'adapte à l'appareil : elle prend le nom de ce qu'il sait faire
/// (Face ID, empreinte digitale…) et n'est actionnable que si une donnée
/// biométrique y est effectivement enrôlée. À défaut, elle reste en retrait
/// avec le motif — un appareil sans capteur n'a rien à proposer, un appareil
/// sans empreinte enregistrée demande un geste dans les réglages du téléphone.
/// Réception des notifications sur cet appareil.
///
/// Couper retire le jeton de l'appareil côté serveur : rien n'est filtré à
/// l'arrivée, plus rien n'est envoyé. La bascule suppose donc un aller-retour
/// réseau, d'où l'interrupteur qui se fige le temps de la réponse.
class _LigneNotifications extends ConsumerStatefulWidget {
  const _LigneNotifications();

  @override
  ConsumerState<_LigneNotifications> createState() =>
      _LigneNotificationsState();
}

class _LigneNotificationsState extends ConsumerState<_LigneNotifications> {
  /// `null` tant que la préférence n'est pas relue : la ligne garde sa place
  /// sans afficher une position qu'elle ne connaît pas encore.
  bool? _active;
  bool _occupee = false;

  /// Position visée pendant la bascule, pour que l'interrupteur suive le doigt
  /// sans attendre le serveur.
  bool? _cible;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final active = await ref.read(receptionPushProvider).estActive();
    if (!mounted) return;
    setState(() => _active = active);
  }

  Future<void> _basculer(bool active) async {
    setState(() {
      _occupee = true;
      _cible = active;
    });

    final reception = ref.read(receptionPushProvider);
    final erreur =
        active ? await reception.activer() : await reception.couper();

    if (!mounted) return;
    setState(() {
      _occupee = false;
      _cible = null;
      // Une activation refusée par le système ne prend pas ; une coupure, si —
      // son message éventuel n'est qu'un avertissement de synchronisation.
      _active = active ? erreur == null : false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(erreur ??
            (active
                ? 'Notifications activées sur cet appareil.'
                : 'Notifications coupées sur cet appareil.')),
        backgroundColor: erreur == null ? AppColors.primary : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final utilisable = active != null && !_occupee;

    return SettingsTile(
      icon: active == false
          ? Icons.notifications_off_outlined
          : Icons.notifications_outlined,
      title: 'Notifications',
      description: switch (active) {
        null => 'Lecture du réglage…',
        true => 'Recevoir les alertes de gestion sur cet appareil',
        false => 'Cet appareil ne recevra aucune alerte',
      },
      onTap: utilisable ? () => _basculer(!active) : null,
      trailing: SettingsSwitch(
        value: _cible ?? active ?? false,
        onChanged: utilisable ? _basculer : null,
      ),
    );
  }
}

class _LigneBiometrie extends ConsumerStatefulWidget {
  const _LigneBiometrie();

  @override
  ConsumerState<_LigneBiometrie> createState() => _LigneBiometrieState();
}

class _LigneBiometrieState extends ConsumerState<_LigneBiometrie> {
  BiometricAvailability? _dispo;
  bool _active = false;
  bool _occupee = false;

  /// Position visée pendant la bascule. L'interrupteur s'y place aussitôt :
  /// la validation biométrique se joue dans la popup de l'OS, la page n'a rien
  /// à faire attendre derrière elle. Revient à `null` une fois l'OS retiré.
  bool? _cible;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    final dispo = await notifier.biometricAvailability();
    final active = await notifier.isBiometricsEnabled();
    if (!mounted) return;
    setState(() {
      _dispo = dispo;
      _active = active;
    });
  }

  Future<void> _basculer(bool active) async {
    setState(() {
      _occupee = true;
      _cible = active;
    });
    final notifier = ref.read(authNotifierProvider.notifier);

    // L'activation passe par une validation biométrique de l'OS : sans elle,
    // on rangerait la clé du coffre pour quelqu'un qui ne saura pas s'en servir.
    String? erreur;
    if (active) {
      erreur = await notifier.enableBiometrics();
    } else {
      await notifier.disableBiometrics();
    }

    if (!mounted) return;
    setState(() {
      _occupee = false;
      _cible = null;
      _active = active && erreur == null;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(erreur ??
            (active
                ? 'Déverrouillage biométrique activé.'
                : 'Déverrouillage biométrique désactivé.')),
        backgroundColor: erreur == null ? AppColors.primary : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dispo = _dispo;
    // Le temps de la détection, la ligne garde sa place sans clignoter.
    final utilisable = (dispo?.disponible ?? false) && !_occupee;

    return SettingsTile(
      icon: dispo?.icone ?? Icons.fingerprint_rounded,
      title: 'Biométrie',
      description: switch (dispo) {
        null => 'Vérification de cet appareil…',
        BiometricAvailability(disponible: true, :final libelleAvecArticle) =>
          'Ouvrir l\'application avec $libelleAvecArticle, '
              'sans saisir le code TMK',
        BiometricAvailability(:final raison?) => raison,
        _ => 'Cet appareil ne dispose pas de capteur biométrique',
      },
      // La ligne entière reste tactile quand le réglage l'est : basculer se
      // fait aussi bien en touchant la ligne qu'en poussant l'interrupteur.
      onTap: utilisable ? () => _basculer(!_active) : null,
      // Pas d'indicateur d'attente pendant la bascule : la popup système
      // occupe déjà l'écran, un cercle qui tourne derrière elle n'apprendrait
      // rien. L'interrupteur montre la position visée et n'accepte plus de
      // geste tant que l'OS n'a pas répondu.
      trailing: SettingsSwitch(
        value: _cible ?? _active,
        onChanged: utilisable ? _basculer : null,
      ),
    );
  }
}

/// Actions de compte révélées par « Mon profil », une par ligne.
///
/// Reprend les briques de la liste de réglages ([SettingsCard] /
/// [SettingsTile]) — icône à gauche, chevron à droite — mais posées à même le
/// bandeau : le bloc de profil garde une seule et même teinte, du nom jusqu'à
/// la dernière action.
class _ActionsProfil extends StatelessWidget {
  final bool avecDescriptions;

  const _ActionsProfil({required this.avecDescriptions});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      sansFond: true,
      children: [
        // La fiche vit dans le référentiel d'identité, pas en base : l'écran
        // lit et écrit `/v1/utilisateurs/moi`, cadré sur le jeton.
        SettingsTile(
          icon: Icons.person_outline_rounded,
          title: 'Mes informations personnelles',
          description: avecDescriptions
              ? 'Nom, adresse e-mail et téléphone du compte'
              : null,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MonProfilPage()),
          ),
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
///
/// Pastille purement décorative, sans réaction au doigt ni au pointeur : ni
/// ondulation, ni assombrissement, ni survol. Le seul retour visuel du geste
/// est le mouvement du volet lui-même, chevron compris — d'où un
/// [GestureDetector] plutôt qu'un `InkWell`.
class _MonProfilBouton extends StatelessWidget {
  /// Avancement du dépli, de 0 (replié) à 1 (déplié) : le chevron pivote au
  /// rythme du volet, glissement de la poignée compris.
  final double avancement;
  final VoidCallback onTap;

  const _MonProfilBouton({required this.avancement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(_kPillRadius),
        ),
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
            // une fois ouvert — et à mi-course entre les deux.
            Transform.rotate(
              angle: (0.25 - 0.5 * avancement) * 2 * math.pi,
              child: const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.dark),
            ),
          ],
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

/// Pastille du nombre de notifications non lues.
///
/// Rien n'est affiché quand le compte est à zéro : un badge vide attire l'œil
/// pour rien. Au-delà de 99, on s'arrête à « 99+ » plutôt que d'élargir la
/// pastille au point de déformer la ligne.
class _BadgeNonLues extends StatelessWidget {
  final int nonLues;

  const _BadgeNonLues(this.nonLues);

  @override
  Widget build(BuildContext context) {
    if (nonLues <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        nonLues > 99 ? '99+' : '$nonLues',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
