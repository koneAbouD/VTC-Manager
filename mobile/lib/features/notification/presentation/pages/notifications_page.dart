import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../data/notification_api.dart';
import '../notification_style.dart';
import '../providers/notification_providers.dart';

/// Marges de la page et écart entre deux journées.
const double _kPagePadding = 16;

/// Arrondi des cartes de journée, aligné sur celles de la page Paramètres.
const double _kCardRadius = 16;

/// Marge intérieure gauche d'une ligne. Un cran plus serré que la marge de
/// page : l'icône occupe déjà la colonne de gauche.
const double _kLignePadding = 12;

/// Largeur de la colonne d'icône. Conservée telle quelle bien que l'icône soit
/// nue : c'est elle qui aligne titres et filets d'une ligne à l'autre.
const double _kColonneIcone = 36;

/// Décalage du filet séparant deux notifications d'une même journée : marge +
/// colonne d'icône + gouttière, pour que le trait démarre sous le titre.
const double _kDividerIndent = _kLignePadding + _kColonneIcone + 12;

/// Centre de notifications : tout ce qui a été notifié, lu ou non.
///
/// Il existe parce qu'une notification balayée sur l'écran d'accueil du
/// téléphone est perdue à jamais — ce qui n'est pas acceptable pour des alertes
/// qui portent sur de l'argent ou sur des véhicules immobilisés.
///
/// La liste est groupée par journée : sur un centre qui reçoit plusieurs
/// alertes par jour, « quand » est la première question qu'on se pose, et une
/// suite d'horodatages ligne à ligne y répond moins bien qu'un titre de section.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _refRafraichi = false;

  /// Filtre « Non lues » : replie la liste sur ce qui reste à traiter.
  bool _nonLuesSeules = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ouvrir la page vaut demande de relecture : une notification reçue
    // application fermée ou en arrière-plan n'a rien invalidé côté application,
    // et le contenu en mémoire peut dater de plusieurs heures. La liste
    // précédente reste affichée pendant l'appel — le rafraîchissement ne
    // renvoie donc personne sur un écran de chargement.
    //
    // Ici et non dans initState : `ref.invalidate` dépend du ProviderScope,
    // indisponible pendant initState.
    if (!_refRafraichi) {
      _refRafraichi = true;
      ref.invalidate(centreNotificationsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final centre = ref.watch(centreNotificationsProvider);
    final aDesNotifications =
        centre.valueOrNull?.notifications.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Notifications',
        // Le filtre occupe la place de l'action, à l'opposé du bouton retour :
        // il reste sous le pouce sans coûter une ligne à la liste. Le compte
        // des non-lues qu'il porte dispense d'un `badge` d'[AppHeader], qui
        // déborderait de sa hauteur préférée.
        action: aDesNotifications
            ? _FiltreEntete(
                nonLuesSeules: _nonLuesSeules,
                nonLues: centre.valueOrNull?.nonLues ?? 0,
                onChanged: (v) => setState(() => _nonLuesSeules = v),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(centreNotificationsProvider.future),
        child: centre.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const _Message(
            icone: Icons.cloud_off_rounded,
            titre: 'Notifications indisponibles',
            detail: 'Tirez vers le bas pour réessayer.',
          ),
          data: _corps,
        ),
      ),
    );
  }

  Widget _corps(CentreNotifications centre) {
    if (centre.notifications.isEmpty) {
      return const _Message(
        icone: Icons.notifications_none_rounded,
        titre: 'Aucune notification',
        detail: 'Les alertes de gestion apparaîtront ici.',
      );
    }

    final liste = _nonLuesSeules
        ? centre.notifications.where((n) => !n.lue).toList()
        : centre.notifications;

    return Column(
      children: [
        // Le filtre est passé dans l'en-tête ; reste ici l'action de masse,
        // qui n'a de sens que s'il y a quelque chose à marquer.
        if (centre.nonLues > 0)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  _kPagePadding, 4, _kPagePadding - 4, 4),
              child: TextButton.icon(
                onPressed: _toutMarquerLu,
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('Tout marquer comme lu'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        Expanded(
          child: liste.isEmpty
              ? const _Message(
                  icone: Icons.done_all_rounded,
                  titre: 'Tout est lu',
                  detail: 'Aucune notification en attente.',
                )
              : _ListeGroupee(
                  journees: _parJournee(liste),
                  onTap: _marquerLue,
                ),
        ),
      ],
    );
  }

  Future<void> _toutMarquerLu() async {
    try {
      await ref.read(notificationApiProvider).marquerToutesLues();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marquage impossible, réessayez.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    ref.invalidate(centreNotificationsProvider);
  }

  /// Un appui vaut accusé de lecture, rien de plus : la ligne perd son fond
  /// teinté et sa pastille, et l'on reste sur la liste. Le texte complet est
  /// déjà sous les yeux — partir vers un autre écran faisait perdre le fil de
  /// ce qu'on était en train de dépiler.
  Future<void> _marquerLue(NotificationItem notification) async {
    if (notification.lue) return;
    try {
      await ref.read(notificationApiProvider).marquerLue(notification.id);
      ref.invalidate(centreNotificationsProvider);
    } catch (_) {
      // Sans conséquence : la notification reste non lue, ce qui est la vérité.
    }
  }
}

/// Notifications d'une même journée, sous le libellé qui la désigne.
typedef _Journee = ({String libelle, List<NotificationItem> items});

/// Découpe la liste en journées.
///
/// Le regroupement est contigu — le backend rend les notifications de la plus
/// récente à la plus ancienne, deux notifications d'un même jour se suivent
/// donc toujours.
List<_Journee> _parJournee(List<NotificationItem> notifications) {
  final journees = <_Journee>[];
  for (final n in notifications) {
    final libelle = _libelleJournee(n.creeLe);
    if (journees.isEmpty || journees.last.libelle != libelle) {
      journees.add((libelle: libelle, items: [n]));
    } else {
      journees.last.items.add(n);
    }
  }
  return journees;
}

/// Titre de section d'une journée : relatif tant qu'il reste parlant, daté
/// au-delà — passé une semaine, « il y a 12 jours » demande un calcul là où une
/// date se lit.
String _libelleJournee(DateTime? date) {
  if (date == null) return 'Sans date';

  final jour = DateUtils.dateOnly(date);
  final ecart = DateUtils.dateOnly(DateTime.now()).difference(jour).inDays;

  if (ecart == 0) return "Aujourd'hui";
  if (ecart == 1) return 'Hier';
  if (ecart < 7) return _capitaliser(DateFormat.EEEE('fr_FR').format(date));
  if (jour.year == DateTime.now().year) {
    return DateFormat('d MMMM', 'fr_FR').format(date);
  }
  return DateFormat('d MMMM yyyy', 'fr_FR').format(date);
}

String _capitaliser(String valeur) =>
    valeur.isEmpty ? valeur : valeur[0].toUpperCase() + valeur.substring(1);

/// Liste des journées : un titre, puis une carte réunissant les notifications
/// du jour, séparées par un filet.
class _ListeGroupee extends StatelessWidget {
  final List<_Journee> journees;
  final void Function(NotificationItem) onTap;

  const _ListeGroupee({required this.journees, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        _kPagePadding,
        4,
        _kPagePadding,
        _kPagePadding + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: journees.length,
      itemBuilder: (_, i) {
        final journee = journees[i];
        return Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  journee.libelle.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.hint,
                  ),
                ),
              ),
              _CarteJournee(items: journee.items, onTap: onTap),
            ],
          ),
        );
      },
    );
  }
}

/// Carte d'une journée : surface blanche, bordure fine, lignes séparées par un
/// filet — même langage visuel que les cartes de la page Paramètres.
class _CarteJournee extends StatelessWidget {
  final List<NotificationItem> items;
  final void Function(NotificationItem) onTap;

  const _CarteJournee({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lignes = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        lignes.add(const Divider(
          height: 1,
          thickness: 1,
          indent: _kDividerIndent,
          color: AppColors.border,
        ));
      }
      lignes.add(_Ligne(
        notification: items[i],
        onTap: () => onTap(items[i]),
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      // Pour que le fond des non-lues et l'effet d'appui suivent les arrondis.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: Column(children: lignes),
      ),
    );
  }
}

/// Une notification dans la liste.
///
/// Les non-lues se distinguent par un fond teinté et une pastille — pas par le
/// gras seul, difficile à repérer d'un coup d'œil sur une liste dense.
class _Ligne extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const _Ligne({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nonLue = !notification.lue;
    final accent = couleurNotification(notification.type);

    return Material(
      color: nonLue ? AppColors.primaryTint : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_kLignePadding, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône nue : la couleur du type suffit à la distinguer, sans
              // fond. La boîte garde ses dimensions pour que titres et filets
              // séparateurs restent alignés.
              SizedBox(
                width: _kColonneIcone,
                height: _kColonneIcone,
                child: Icon(
                  iconeNotification(notification.type),
                  size: 19,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.titre,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: nonLue ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.corps,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.label,
                      ),
                    ),
                    // Le détail — chauffeur, véhicule, montants — n'existe que
                    // sur cet écran : il n'a jamais été poussé vers le
                    // téléphone. Il se lit dans la continuité du corps, au même
                    // style : le noir et la graisse restent au titre seul.
                    if (notification.detail case final detail?
                        when detail.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.label,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Colonne de droite : l'heure suffit, le jour étant porté par le
              // titre de section.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (notification.creeLe != null)
                    Text(
                      DateFormat.Hm('fr_FR').format(notification.creeLe!),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.hint,
                      ),
                    ),
                  if (nonLue) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filtre de la liste, logé dans l'en-tête : tout, ou seulement ce qui reste
/// à lire.
///
/// Les deux choix tiennent dans une seule pilule, plus basse et plus serrée
/// que les boutons d'[AppHeader] : le titre est centré sur la barre, et chaque
/// pixel pris ici est un pixel qu'il perd. Pour la même raison, le nombre de
/// non-lues n'est pas repris dans le libellé — la cloche de l'accueil le porte
/// déjà.
class _FiltreEntete extends StatelessWidget {
  final bool nonLuesSeules;
  final int nonLues;
  final ValueChanged<bool> onChanged;

  const _FiltreEntete({
    required this.nonLuesSeules,
    required this.nonLues,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // Le titre garde toujours sa part de la barre : passé cette largeur, ce
      // sont les libellés du filtre qui s'abrègent, pas l'en-tête qui déborde
      // (compte à deux chiffres, gros réglage de taille de texte…).
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.55),
      child: Container(
        height: 30,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.headerButton,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: _Segment(
                libelle: 'Toutes',
                actif: !nonLuesSeules,
                onTap: () => onChanged(false),
              ),
            ),
            Flexible(
              child: _Segment(
                libelle: 'Non lues',
                actif: nonLuesSeules,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segment du filtre, plein quand il est actif.
class _Segment extends StatelessWidget {
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  const _Segment({
    required this.libelle,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: actif ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // `widthFactor: 1` : le segment se règle sur son libellé. Centré
          // sans ce facteur, il s'étirerait sur toute la largeur offerte au
          // filtre — et repousserait le titre de la barre.
          child: Align(
            widthFactor: 1,
            child: Text(
              libelle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: actif ? AppColors.surface : AppColors.label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;

  const _Message({
    required this.icone,
    required this.titre,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    // Liste défilable même vide : sans cela, le geste de rafraîchissement
    // n'aurait rien à quoi s'accrocher.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Icon(icone, size: 52, color: AppColors.hint),
        const SizedBox(height: 14),
        Text(
          titre,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.label),
          ),
        ),
      ],
    );
  }
}
