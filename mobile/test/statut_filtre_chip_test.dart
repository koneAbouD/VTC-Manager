import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/core/theme/app_colors.dart';
import 'package:vtc_manager/core/theme/app_palette.dart';
import 'package:vtc_manager/core/widgets/statut_filtre_chip.dart';

void main() {
  tearDown(() => AppColors.appliquer(AppAccent.vert, Brightness.light));

  Future<void> monter(WidgetTester tester, {required bool selected}) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                StatutFiltreChip(
                  label: 'Encaissé',
                  selected: selected,
                  // Couleur du statut : ne doit pas teinter la pastille.
                  color: AppColors.positive,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ));

  BoxDecoration decoration(WidgetTester tester) => tester
      .widget<AnimatedContainer>(find.byType(AnimatedContainer))
      .decoration! as BoxDecoration;

  testWidgets("sélectionnée, la pastille prend la couleur d'accent",
      (tester) async {
    AppColors.appliquer(AppAccent.violet, Brightness.light);
    await monter(tester, selected: true);

    expect(decoration(tester).color, AppAccent.violet.primary);
    final texte = tester.widget<Text>(find.text('Encaissé'));
    expect(texte.style!.color, AppColors.onPrimary);
  });

  testWidgets('non sélectionnée, elle reste neutre', (tester) async {
    AppColors.appliquer(AppAccent.violet, Brightness.light);
    await monter(tester, selected: false);

    expect(decoration(tester).color, AppColors.surface);
  });

  testWidgets('elle suit aussi la variante sombre de l\'accent',
      (tester) async {
    AppColors.appliquer(AppAccent.bleu, Brightness.dark);
    await monter(tester, selected: true);

    expect(decoration(tester).color, AppAccent.bleu.primaryNuit);
  });
}
