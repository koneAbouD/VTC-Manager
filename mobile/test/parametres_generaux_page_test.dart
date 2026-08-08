import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/core/error/exception.dart';
import 'package:vtc_manager/features/parametrage/data/parametrage_api.dart';
import 'package:vtc_manager/features/parametrage/presentation/pages/parametres_generaux_page.dart';
import 'package:vtc_manager/features/parametrage/presentation/providers/parametrage_providers.dart';

/// Faux accès REST : mémorise l'appel d'écriture, ou le fait échouer.
class _FakeParametrageApi implements ParametrageApi {
  _FakeParametrageApi({this.erreur});

  final Object? erreur;
  final List<String> valeursEnvoyees = [];

  @override
  Future<ParametreGeneral> mettreAJourParametre(
      String cle, String valeur) async {
    valeursEnvoyees.add(valeur);
    if (erreur != null) throw erreur!;
    return ParametreGeneral(
        cle: cle, valeur: valeur, libelle: '', description: '');
  }

  // Les autres méthodes du client ne sont pas sollicitées par cette page.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const parametres = [
    ParametreGeneral(
      cle: 'DUREE_AMORTISSEMENT_MOIS',
      valeur: '60',
      libelle: "Durée d'amortissement des véhicules (mois)",
      description: "Durée d'amortissement linéaire par défaut appliquée à "
          'toute la flotte, en mois (60 = 5 ans).',
    ),
    ParametreGeneral(
      cle: 'PROVISION_CREANCES_TAUX_8_30',
      valeur: '25',
      libelle: 'Provision créances 8-30 jours (%)',
      description:
          'Taux de dépréciation appliqué aux créances de 8 à 30 jours.',
    ),
  ];

  Future<void> monter(
    WidgetTester tester, {
    List<ParametreGeneral> liste = parametres,
    ParametrageApi? api,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        parametresProvider.overrideWith((ref) async => liste),
        if (api != null) parametrageApiProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(home: ParametresGenerauxPage()),
    ));
    await tester.pumpAndSettle();
  }

  /// Laisse expirer le délai d'inactivité qui déclenche l'enregistrement.
  Future<void> attendreEnvoi(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('affiche chaque valeur avec son unité, groupée par domaine',
      (tester) async {
    await monter(tester);

    expect(find.text('AMORTISSEMENT'), findsOneWidget);
    expect(find.text('PROVISIONS SUR CRÉANCES'), findsOneWidget);
    expect(find.text('60 mois'), findsOneWidget);
    // La conversion en années accompagne la durée : c'est elle que l'on lit.
    expect(find.text('5 ans'), findsOneWidget);
    expect(find.text('25 %'), findsOneWidget);
  });

  testWidgets(
      'range une clé inconnue dans « Autres réglages » plutôt que '
      'de la perdre', (tester) async {
    await monter(tester, liste: const [
      ParametreGeneral(
        cle: 'DEVISE_PAR_DEFAUT',
        valeur: 'XOF',
        libelle: 'Devise',
        description: '',
      ),
    ]);

    expect(find.text('AUTRES RÉGLAGES'), findsOneWidget);
    expect(find.text('XOF'), findsOneWidget);
  });

  testWidgets('déplie la roulette dans la ligne, sans rien ouvrir par-dessus',
      (tester) async {
    await monter(tester);

    expect(find.byType(CupertinoPicker), findsNothing);

    await tester.tap(find.text('60 mois'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsOneWidget);
    // Aucune route n'a été empilée : on est resté sur la page.
    expect(find.byType(ParametresGenerauxPage), findsOneWidget);
    // Plus rien à valider : la roulette est le seul contrôle de la ligne.
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('cale la roulette sur la largeur du bouton de valeur',
      (tester) async {
    // Sur une tablette, la ligne est large : la roulette ne doit pas s'étirer
    // avec elle.
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await monter(tester);
    await tester.tap(find.text('60 mois'));
    await tester.pumpAndSettle();

    final roulette = tester.getSize(find.byType(CupertinoPicker));
    final ligne = tester.getSize(find.byType(ParametresGenerauxPage));
    expect(roulette.width, lessThan(ligne.width / 3));
  });

  testWidgets('n\'ouvre qu\'une roulette à la fois', (tester) async {
    await monter(tester);

    await tester.tap(find.text('60 mois'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25 %'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsOneWidget);
  });

  testWidgets('propose un champ libre quand la clé n\'a pas de barème',
      (tester) async {
    await monter(tester, liste: const [
      ParametreGeneral(
        cle: 'DEVISE_PAR_DEFAUT',
        valeur: 'XOF',
        libelle: 'Devise',
        description: '',
      ),
    ]);

    await tester.tap(find.text('XOF'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('le bouton suit la roulette pendant le geste', (tester) async {
    final api = _FakeParametrageApi();
    await monter(tester, api: api);

    await tester.tap(find.text('60 mois'));
    await tester.pumpAndSettle();
    // Deux crans plus loin (pas de six mois), sans laisser filer le délai
    // d'enregistrement : on observe l'état intermédiaire.
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -68));
    await tester.pump();

    // « 72 mois » deux fois : sous le curseur de la roulette et sur le bouton,
    // qui a suivi. La conversion en années suit elle aussi.
    expect(find.text('72 mois'), findsNWidgets(2));
    expect(find.text('6 ans'), findsOneWidget);

    // Rien n'annonce l'envoi : ni témoin d'activité, ni mention sous le
    // bouton.
    await attendreEnvoi(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('nregistrement'), findsNothing);
  });

  testWidgets('enregistre de lui-même la valeur choisie, sans validation',
      (tester) async {
    final api = _FakeParametrageApi();
    await monter(tester, api: api);

    await tester.tap(find.text('60 mois'));
    await tester.pumpAndSettle();

    // Deux crans plus loin sur la roulette : le pas est de six mois.
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -68));
    await tester.pump();
    // Rien ne part sur-le-champ : le geste doit d'abord s'arrêter.
    expect(api.valeursEnvoyees, isEmpty);

    await attendreEnvoi(tester);

    expect(api.valeursEnvoyees, ['72']);
    // La ligne reste dépliée : on peut continuer d'ajuster.
    expect(find.byType(CupertinoPicker), findsOneWidget);
    // Un succès ne s'annonce pas : pas de bandeau à écarter.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('n\'envoie qu\'une fois quand la roulette défile plusieurs crans',
      (tester) async {
    final api = _FakeParametrageApi();
    await monter(tester, api: api);

    await tester.tap(find.text('60 mois'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -34));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -34));
    await tester.pumpAndSettle();
    await attendreEnvoi(tester);

    expect(api.valeursEnvoyees, hasLength(1));
  });

  testWidgets('envoie sans attendre quand on replie la ligne', (tester) async {
    final api = _FakeParametrageApi();
    await monter(tester, api: api);

    await tester.tap(find.text('60 mois'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -68));
    // Assez pour que la roulette se cale, pas assez pour l'envoi automatique.
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.valeursEnvoyees, isEmpty);

    // Replier n'annule pas : le réglage part tout de suite.
    await tester.tap(find.text("Durée d'amortissement des véhicules (mois)"));
    await tester.pumpAndSettle();

    expect(api.valeursEnvoyees, ['72']);
  });

  testWidgets('garde la sélection sous les yeux quand le serveur refuse',
      (tester) async {
    final api = _FakeParametrageApi(
        erreur: const ApiException(400, 'Durée non autorisée.'));
    await monter(tester, api: api);

    await tester.tap(find.text('60 mois'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -68));
    await tester.pumpAndSettle();
    await attendreEnvoi(tester);

    // Le refus rappelle ce qui reste en vigueur, la roulette ne bouge pas.
    expect(
      find.text('Durée non autorisée. Valeur en vigueur : 60 mois.'),
      findsOneWidget,
    );
    expect(find.byType(CupertinoPicker), findsOneWidget);
  });
}
