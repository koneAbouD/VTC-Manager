import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vtc_manager/features/notification/data/notification_api.dart';
import 'package:vtc_manager/features/notification/presentation/pages/notifications_page.dart';
import 'package:vtc_manager/features/notification/presentation/providers/notification_providers.dart';

void main() {
  // La page date ses lignes en français ; `main.dart` fait de même au
  // démarrage, sans quoi le premier DateFormat lèverait.
  setUpAll(() => initializeDateFormatting('fr_FR', null));

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

  testWidgets('groupe les notifications par journée', (tester) async {
    final maintenant = DateTime.now();
    await monter(
      tester,
      CentreNotifications(
        notifications: [
          NotificationItem(
            id: 1,
            type: 'RECETTE_ENCAISSEE',
            titre: 'Versement du jour',
            corps: 'Recette encaissée.',
            lue: false,
            creeLe: maintenant,
          ),
          NotificationItem(
            id: 2,
            type: 'PENALITE_APPLIQUEE',
            titre: 'Pénalité de la veille',
            corps: 'Pénalité appliquée.',
            lue: true,
            creeLe: maintenant.subtract(const Duration(days: 1)),
          ),
        ],
        nonLues: 1,
      ),
    );

    expect(find.text("AUJOURD'HUI"), findsOneWidget);
    expect(find.text('HIER'), findsOneWidget);
  });

  testWidgets('le filtre « Non lues » écarte ce qui est déjà lu',
      (tester) async {
    await monter(
      tester,
      const CentreNotifications(
        notifications: [
          NotificationItem(
            id: 1,
            type: 'RECETTE_ENCAISSEE',
            titre: 'À traiter',
            corps: 'Recette encaissée.',
            lue: false,
          ),
          NotificationItem(
            id: 2,
            type: 'PENALITE_APPLIQUEE',
            titre: 'Déjà vue',
            corps: 'Pénalité appliquée.',
            lue: true,
          ),
        ],
        nonLues: 1,
      ),
    );

    expect(find.text('Déjà vue'), findsOneWidget);

    await tester.tap(find.text('Non lues'));
    await tester.pumpAndSettle();

    expect(find.text('À traiter'), findsOneWidget);
    expect(find.text('Déjà vue'), findsNothing);
  });

  testWidgets('loge le filtre dans l\'en-tête, même sur un écran étroit',
      (tester) async {
    // Le filtre partage la barre avec le bouton retour et le titre : sur un
    // petit téléphone, rien ne doit déborder.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await monter(
      tester,
      CentreNotifications(
        notifications: [
          for (var i = 1; i <= 12; i++)
            NotificationItem(
              id: i,
              type: 'RECETTE_ENCAISSEE',
              titre: 'Alerte $i',
              corps: 'Recette encaissée.',
              lue: false,
            ),
        ],
        nonLues: 12,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Toutes'), findsOneWidget);
    expect(find.text('Non lues'), findsOneWidget);
    // L'action de masse a quitté l'en-tête pour le haut de la liste.
    expect(find.text('Tout marquer comme lu'), findsOneWidget);
  });

  testWidgets('garde le titre centré une fois le filtre posé à côté',
      (tester) async {
    await monter(
      tester,
      const CentreNotifications(
        notifications: [
          NotificationItem(
            id: 1,
            type: 'RECETTE_ENCAISSEE',
            titre: 'Alerte',
            corps: 'Recette encaissée.',
            lue: false,
          ),
        ],
        nonLues: 1,
      ),
    );

    final ecran = tester.getSize(find.byType(MaterialApp));
    final titre = tester.getRect(find.text('Notifications'));

    expect(titre.center.dx, moreOrLessEquals(ecran.width / 2, epsilon: 1));
  });
}
