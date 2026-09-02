import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/core/theme/app_colors.dart';
import 'package:vtc_manager/core/widgets/detail_carte.dart';

/// La ligne « Chauffeur » d'une fiche de détail est modifiable, mais elle doit
/// rester une ligne d'info comme les autres : c'est la valeur qu'on touche, pas
/// le libellé, et rien dans la carte ne doit bouger de place.
void main() {
  Future<void> poser(WidgetTester tester,
      {bool verrouille = false, VoidCallback? onTap}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DetailInfoCard(children: [
          const DetailInfoRow(
              Icons.calendar_today_outlined, 'Date', '14/08/2026'),
          DetailInfoRowAction(
            Icons.person_outline_rounded,
            'Chauffeur',
            'Kouassi Yao',
            verrouille: verrouille,
            motifVerrou: verrouille ? 'Un arrêté a figé cette créance.' : null,
            onTap: onTap ?? () {},
          ),
          const DetailInfoRow(
              Icons.payments_outlined, 'Attendu', '15 000 XOF'),
        ]),
      ),
    ));
  }

  testWidgets('la valeur reste alignée à droite comme celles des autres lignes',
      (tester) async {
    await poser(tester);

    final droiteDate = tester.getBottomRight(find.text('14/08/2026')).dx;
    final droiteAttendu = tester.getBottomRight(find.text('15 000 XOF')).dx;
    // Le chevron suit la valeur : c'est lui qui touche le bord, à la place du
    // texte. Le décalage doit rester celui d'une icône, pas d'un bloc.
    final droiteNom = tester.getBottomRight(find.text('Kouassi Yao')).dx;

    expect(droiteDate, moreOrLessEquals(droiteAttendu, epsilon: 0.5));
    expect(droiteDate - droiteNom, lessThan(20));
  });

  testWidgets('le libellé « Chauffeur » ne déclenche rien : seul le nom répond',
      (tester) async {
    var taps = 0;
    await poser(tester, onTap: () => taps++);

    await tester.tap(find.text('Chauffeur'));
    await tester.pump();
    expect(taps, 0, reason: 'le mot « Chauffeur » n’est pas un bouton');

    await tester.tap(find.text('Kouassi Yao'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('la ligne garde les mesures des autres : icône et libellé intacts',
      (tester) async {
    await poser(tester);

    // Les trois libellés partent du même bord gauche, et les trois icônes aussi.
    final gaucheDate = tester.getTopLeft(find.text('Date')).dx;
    final gaucheChauffeur = tester.getTopLeft(find.text('Chauffeur')).dx;
    expect(gaucheChauffeur, moreOrLessEquals(gaucheDate, epsilon: 0.5));

    // Le libellé garde la couleur discrète des rubriques, il n'est pas teinté
    // comme le serait un bouton.
    final libelle = tester.widget<Text>(find.text('Chauffeur'));
    expect(libelle.style?.color, AppColors.label);

    // Et la valeur garde le noir des autres : seul le chevron dit l'action.
    final nom = tester.widget<Text>(find.text('Kouassi Yao'));
    expect(nom.style?.color, AppColors.dark);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('verrouillée, la valeur porte un cadenas et ne réagit plus',
      (tester) async {
    var taps = 0;
    await poser(tester, verrouille: true, onTap: () => taps++);

    final nom = tester.widget<Text>(find.text('Kouassi Yao'));
    expect(nom.style?.color, AppColors.dark);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

    await tester.tap(find.text('Kouassi Yao'));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('un appui prolongé dit pourquoi la valeur est fermée',
      (tester) async {
    await poser(tester, verrouille: true);

    // La bulle vit le temps de l'appui : elle paraît au maintien et s'efface au
    // relâchement. Un longPress complet la ferait disparaître avant l'examen.
    final geste = await tester.startGesture(
        tester.getCenter(find.text('Kouassi Yao')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    expect(find.text('Un arrêté a figé cette créance.'), findsOneWidget);

    await geste.up();
    await tester.pump();
    expect(find.text('Un arrêté a figé cette créance.'), findsNothing);
  });
}
