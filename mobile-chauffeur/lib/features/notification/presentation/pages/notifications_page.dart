import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ligne_card.dart';
import '../../domain/entities/notification_item.dart';
import '../notification_style.dart';
import '../providers/notification_providers.dart';

/// Centre de notifications du chauffeur.
///
/// Il existe parce qu'une notification balayée sur l'écran d'accueil du
/// téléphone est perdue à jamais — ce qui n'est pas acceptable quand elle
/// annonce une pénalité ou une prime à percevoir.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centre = ref.watch(centreNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (centre.valueOrNull != null && centre.value!.nonLues > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Tout marquer comme lu',
              onPressed: () => _toutMarquerLu(ref),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(centreNotificationsProvider);
          await ref.read(centreNotificationsProvider.future);
        },
        child: centre.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _Message(
            icone: Icons.cloud_off_rounded,
            titre: 'Notifications indisponibles',
            detail: 'Tirez vers le bas pour réessayer.',
          ),
          data: (c) => c.notifications.isEmpty
              ? const _Message(
                  icone: Icons.notifications_none_rounded,
                  titre: 'Aucune notification',
                  detail: 'Vos alertes apparaîtront ici.',
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  itemCount: c.notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final n = c.notifications[i];
                    return Opacity(
                      // Les lues s'effacent légèrement : l'œil va d'abord à ce
                      // qui n'a pas encore été vu.
                      opacity: n.lue ? 0.62 : 1,
                      child: LigneCard(
                        icone: iconeNotification(n.type),
                        couleur: couleurNotification(n.type),
                        titre: n.titre,
                        // Le détail — montants versés, reste à devoir — n'a
                        // jamais été poussé vers le téléphone : cet écran est
                        // le seul endroit où le chauffeur peut le lire.
                        sousTitre: [
                          n.corps,
                          ?(n.detail?.isNotEmpty ?? false ? n.detail : null),
                        ].join('\n'),
                        trailing: n.creeLe == null
                            ? null
                            : Text(
                                _quand(n.creeLe!),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.hint,
                                ),
                              ),
                        onTap: () => _marquerLue(ref, n),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _marquerLue(WidgetRef ref, NotificationItem n) async {
    if (n.lue) return;
    await ref.read(marquerNotificationLueUseCaseProvider).call(n.id);
    ref.invalidate(centreNotificationsProvider);
  }

  Future<void> _toutMarquerLu(WidgetRef ref) async {
    await ref.read(marquerNotificationLueUseCaseProvider).toutes();
    ref.invalidate(centreNotificationsProvider);
  }

  /// Ancienneté en clair. Au-delà d'une semaine, la date exacte redevient plus
  /// parlante que « il y a 12 jours ».
  static String _quand(DateTime date) {
    final ecart = DateTime.now().difference(date);
    if (ecart.inMinutes < 1) return "À l'instant";
    if (ecart.inMinutes < 60) return '${ecart.inMinutes} min';
    if (ecart.inHours < 24) return '${ecart.inHours} h';
    if (ecart.inDays == 1) return 'Hier';
    if (ecart.inDays < 7) return '${ecart.inDays} j';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
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
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Icon(icone, size: 50, color: AppColors.hint),
        const SizedBox(height: 12),
        Text(
          titre,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
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
            style: const TextStyle(fontSize: 12.5, color: AppColors.label),
          ),
        ),
      ],
    );
  }
}
