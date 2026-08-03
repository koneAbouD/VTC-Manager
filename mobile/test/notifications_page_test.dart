import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/features/notification/data/notification_api.dart';
import 'package:vtc_manager/features/notification/presentation/pages/notifications_page.dart';
import 'package:vtc_manager/features/notification/presentation/providers/notification_providers.dart';

void main() {
  Future<void> monter(WidgetTester tester, CentreNotifications centre) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        centreNotificationsProvider.overrideWith((ref) async => centre),
      ],
      child: const MaterialApp(home: NotificationsPage()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('s\'ouvre sans lever, en relisant le centre au passage',
      (tester) async {
    // La relecture à l'ouverture a d'abord été posée dans initState, où
    // `ref.invalidate` s'abonne au ProviderScope trop tôt : la page ne
    // s'affichait pas du tout. Ce test monte la page pour de bon.
    await monter(
      tester,
      const CentreNotifications(
        notifications: [
          NotificationItem(
            id: 1,
            type: 'RECETTE_ENCAISSEE',
            titre: 'Versement enregistré',
            corps: 'Votre versement de recette du 03/08 a bien été enregistré.',
            lue: false,
          ),
        ],
        nonLues: 1,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Versement enregistré'), findsOneWidget);
  });

  testWidgets('annonce une liste vide plutôt qu\'un écran nu', (tester) async {
    await monter(tester, CentreNotifications.vide);

    expect(find.text('Aucune notification'), findsOneWidget);
  });
}
