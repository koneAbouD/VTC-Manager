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

  testWidgets("sélectionnée, la pastille se teinte de la couleur d'accent",
      (tester) async {
    AppColors.appliquer(AppAccent.violet, Brightness.light);
    await monter(tester, selected: true);

    final accent = AppAccent.violet.primary;
    final deco = decoration(tester);
    // Fond clair et bordure à l'accent, pas un aplat plein.
    expect(deco.color, accent.withValues(alpha: 0.12));
    expect((deco.border! as Border).top.color, accent.withValues(alpha: 0.5));
    final texte = tester.widget<Text>(find.text('Encaissé'));
    expect(texte.style!.color, accent);
  });

  testWidgets('non sélectionnée, elle reste neutre', (tester) async {
    AppColors.appliquer(AppAccent.violet, Brightness.light);
    await monter(tester, selected: false);

    final deco = decoration(tester);
    expect(deco.color, AppColors.surface);
    expect((deco.border! as Border).top.color, AppColors.border);
  });

  testWidgets('elle suit aussi la variante sombre de l\'accent',
      (tester) async {
    AppColors.appliquer(AppAccent.bleu, Brightness.dark);
    await monter(tester, selected: true);

    expect(decoration(tester).color,
        AppAccent.bleu.primaryNuit.withValues(alpha: 0.12));
  });
}
