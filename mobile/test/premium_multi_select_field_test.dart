import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/core/widgets/premium_select_field.dart';

const _options = [
  SelectOption(value: 1, label: 'Vidange'),
  SelectOption(value: 2, label: 'Freinage'),
  SelectOption(value: 3, label: 'Pneumatique'),
];

/// Champ tenu par un parent qui garde la sélection, comme un formulaire.
class _Hote extends StatefulWidget {
  final List<int> initiales;
  final GlobalKey<FormState>? formKey;
  const _Hote({this.initiales = const [], this.formKey});

  @override
  State<_Hote> createState() => _HoteState();
}

class _HoteState extends State<_Hote> {
  late List<int> valeurs = widget.initiales;
  int appels = 0;

  @override
  Widget build(BuildContext context) => Form(
        key: widget.formKey,
        child: PremiumMultiSelectField<int>(
          values: valeurs,
          options: _options,
          hint: 'Sélectionner les types',
          isRequired: true,
          onChanged: (v) => setState(() {
            appels++;
            valeurs = v;
          }),
        ),
      );
}

/// Referme la feuille en touchant hors d'elle, comme l'utilisateur.
Future<void> _fermer(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

Future<_HoteState> _monter(WidgetTester tester,
    {List<int> initiales = const [], GlobalKey<FormState>? formKey}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: _Hote(initiales: initiales, formKey: formKey)),
  ));
  return tester.state<_HoteState>(find.byType(_Hote));
}

void main() {
  group('champ à choix multiple premium', () {
    testWidgets('cocher plusieurs valeurs puis fermer, dans l\'ordre choisi',
        (tester) async {
      final hote = await _monter(tester);
      expect(find.text('Sélectionner les types'), findsOneWidget);

      await tester.tap(find.text('Sélectionner les types'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Freinage'));
      await tester.tap(find.text('Vidange'));
      await tester.pump();
      // La feuille reste ouverte pendant qu'on coche, sans bouton à valider.
      expect(find.text('Tout décocher'), findsOneWidget);
      expect(find.text('Valider'), findsNothing);
      await _fermer(tester);

      expect(hote.valeurs, [2, 1]);
      expect(find.text('Freinage · Vidange'), findsOneWidget);
    });

    testWidgets('décocher retire la valeur', (tester) async {
      final hote = await _monter(tester, initiales: [1, 2]);
      await tester.tap(find.text('Vidange · Freinage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vidange'));
      await _fermer(tester);

      expect(hote.valeurs, [2]);
    });

    testWidgets('fermer par le retour arrière retient aussi la sélection',
        (tester) async {
      final hote = await _monter(tester, initiales: [1]);
      await tester.tap(find.text('Vidange'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pneumatique'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(hote.valeurs, [1, 3]);
    });

    testWidgets('fermer sans rien changer ne signale aucun changement',
        (tester) async {
      final hote = await _monter(tester, initiales: [1]);
      await tester.tap(find.text('Vidange'));
      await tester.pumpAndSettle();
      await _fermer(tester);

      expect(hote.valeurs, [1]);
      expect(hote.appels, 0);
    });

    testWidgets('« Tout décocher » vide la sélection', (tester) async {
      final hote = await _monter(tester, initiales: [1, 3]);
      await tester.tap(find.text('Vidange · Pneumatique'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tout décocher'));
      await tester.pump();
      await _fermer(tester);

      expect(hote.valeurs, isEmpty);
    });

    testWidgets('obligatoire : une sélection vide ne valide pas le formulaire',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      await _monter(tester, formKey: formKey);

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Champ obligatoire'), findsOneWidget);
    });
  });
}
