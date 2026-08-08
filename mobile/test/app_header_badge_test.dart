import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/widgets/app_header.dart';

/// Monte un [AppHeader] en position d'appBar, comme les pages réelles.
Future<void> _pumpHeader(WidgetTester tester, {String? badge, Widget? action}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      appBar: AppHeader(title: 'Notifications', badge: badge, action: action),
      body: const SizedBox.shrink(),
    ),
  ));
}

void main() {
  testWidgets('un en-tête avec badge se pose sans déborder', (tester) async {
    await _pumpHeader(tester, badge: '1 non lue');

    // Un overflow de RenderFlex remonte ici sous forme d'exception de layout.
    expect(tester.takeException(), isNull,
        reason: 'La hauteur réservée doit couvrir titre + pilule.');
    expect(find.text('1 non lue'), findsOneWidget);
  });

  testWidgets('la hauteur réservée augmente avec le badge', (tester) async {
    await _pumpHeader(tester);
    final sansBadge = tester.widget<AppHeader>(find.byType(AppHeader));

    await _pumpHeader(tester, badge: '1 non lue');
    final avecBadge = tester.widget<AppHeader>(find.byType(AppHeader));

    expect(sansBadge.preferredSize.height, 66);
    expect(avecBadge.preferredSize.height,
        greaterThan(sansBadge.preferredSize.height));
  });

  testWidgets('un en-tête sans badge ne déborde pas non plus', (tester) async {
    await _pumpHeader(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('se pose aussi dans le corps d\'une page, sans hauteur imposée',
      (tester) async {
    // `settings_screen` intègre l'en-tête au bandeau de profil, dans une
    // Column : la barre y reçoit une hauteur illimitée et ne doit pas
    // chercher à la remplir.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            AppHeader(title: '', backgroundColor: Colors.transparent),
            Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppHeader)).height, lessThan(200));
  });

  testWidgets('un bouton d\'action se règle sur son libellé, sans s\'étaler',
      (tester) async {
    // Les pages de détail (chauffeur, véhicule) posent un « Modifier » sans
    // titre : il doit rester une pilule, pas occuper toute la barre.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppHeader(
          title: '',
          action: AppHeaderAction(label: 'Modifier', onTap: () {}),
        ),
        body: const SizedBox.shrink(),
      ),
    ));

    final bouton = tester.getSize(find
        .ancestor(
          of: find.text('Modifier'),
          matching: find.byType(Container),
        )
        .first);
    final ecran = tester.getSize(find.byType(MaterialApp));

    expect(bouton.height, 38);
    expect(bouton.width, lessThan(ecran.width / 2));
  });

  testWidgets('le titre reste centré, quelle que soit la largeur de l\'action',
      (tester) async {
    // Une action large — un filtre segmenté, un bouton « Modifier » — ne doit
    // plus pousser le titre vers le bouton retour.
    await _pumpHeader(
      tester,
      action: Container(width: 160, height: 38, color: const Color(0xFFEEEEEE)),
    );

    final ecran = tester.getSize(find.byType(MaterialApp));
    final titre = tester.getRect(find.text('Notifications'));

    expect(titre.center.dx, moreOrLessEquals(ecran.width / 2, epsilon: 1));
  });
}
