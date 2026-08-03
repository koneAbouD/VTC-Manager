import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../data/notification_api.dart';
import '../notification_style.dart';
import '../providers/notification_providers.dart';

/// Centre de notifications : tout ce qui a été notifié, lu ou non.
///
/// Il existe parce qu'une notification balayée sur l'écran d'accueil du
/// téléphone est perdue à jamais — ce qui n'est pas acceptable pour des alertes
/// qui portent sur de l'argent ou sur des véhicules immobilisés.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _refRafraichi = false;

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

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Notifications',
        showBack: true,
        action: centre.maybeWhen(
          data: (c) => c.nonLues > 0
              ? AppHeaderAction(
                  icon: Icons.done_all_rounded,
                  onTap: _toutMarquerLu,
                )
              : null,
          orElse: () => null,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(centreNotificationsProvider.future),
        child: centre.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const _Message(
            icone: Icons.cloud_off_rounded,
            titre: 'Notifications indisponibles',
            detail: 'Tirez vers le bas pour réessayer.',
          ),
          data: (c) => c.notifications.isEmpty
              ? const _Message(
                  icone: Icons.notifications_none_rounded,
                  titre: 'Aucune notification',
                  detail: 'Les alertes de gestion apparaîtront ici.',
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: c.notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _Carte(
                    notification: c.notifications[i],
                    onTap: () => _ouvrir(c.notifications[i]),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _toutMarquerLu() async {
    await ref.read(notificationApiProvider).marquerToutesLues();
    ref.invalidate(centreNotificationsProvider);
  }

  Future<void> _ouvrir(NotificationItem notification) async {
    if (!notification.lue) {
      await ref.read(notificationApiProvider).marquerLue(notification.id);
      ref.invalidate(centreNotificationsProvider);
    }
    // La navigation vers l'écran concerné viendra avec le routeur : depuis le
    // centre, l'utilisateur a déjà le texte complet sous les yeux.
  }
}

/// Une notification dans la liste. Les non-lues se distinguent par une pastille
/// et un fond teinté — pas par le gras seul, difficile à repérer d'un coup
/// d'œil sur une liste dense.
class _Carte extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const _Carte({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nonLue = !notification.lue;

    return Material(
      color: nonLue ? AppColors.primaryTint : AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: couleurNotification(notification.type)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconeNotification(notification.type),
                  size: 20,
                  color: couleurNotification(notification.type),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.titre,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight:
                                  nonLue ? FontWeight.w700 : FontWeight.w600,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        if (nonLue)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                    // téléphone. C'est ce qui distingue deux encaissements
                    // successifs, d'où l'appui typographique.
                    if (notification.detail case final detail?
                        when detail.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark,
                        ),
                      ),
                    ],
                    if (notification.creeLe != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _quand(notification.creeLe!),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.hint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ancienneté en clair. Au-delà d'une semaine, la date exacte redevient plus
  /// parlante que « il y a 12 jours ».
  static String _quand(DateTime date) {
    final ecart = DateTime.now().difference(date);
    if (ecart.inMinutes < 1) return "À l'instant";
    if (ecart.inMinutes < 60) return 'Il y a ${ecart.inMinutes} min';
    if (ecart.inHours < 24) return 'Il y a ${ecart.inHours} h';
    if (ecart.inDays == 1) return 'Hier';
    if (ecart.inDays < 7) return 'Il y a ${ecart.inDays} jours';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
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
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
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
