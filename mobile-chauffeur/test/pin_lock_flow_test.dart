import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_pin/tmk_pin.dart';
import 'package:vtc_chauffeur/core/network/session_manager.dart';
import 'package:vtc_chauffeur/features/auth/presentation/pages/login_page.dart';
import 'package:vtc_chauffeur/features/auth/presentation/pages/pin_lock_page.dart';
import 'package:vtc_chauffeur/features/auth/presentation/pages/pin_setup_page.dart';
import 'package:vtc_chauffeur/features/auth/presentation/providers/auth_controller.dart';
import 'package:vtc_chauffeur/features/compte/presentation/pages/home_page.dart';
import 'package:vtc_chauffeur/main.dart';

/// Le stockage sécurisé passe par un canal de plateforme : en test, on le
/// remplace par une simple map.
class _FakeSecureStorageChannel {
  static const _channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  final Map<String, String> values = {};

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return values[key];
        case 'write':
          values[key!] = args['value'] as String;
          return null;
        case 'delete':
          values.remove(key);
          return null;
        case 'deleteAll':
          values.clear();
          return null;
        case 'readAll':
          return Map<String, String>.from(values);
        case 'containsKey':
          return values.containsKey(key);
        default:
          return null;
      }
    });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

void main() {
  late _FakeSecureStorageChannel storage;

  PinService fastPin() =>
      PinService(const PinStore(SecureKeyValueStore()), iterations: 1000);

  setUp(() {
    storage = _FakeSecureStorageChannel()..install();
  });

  tearDown(() => storage.remove());

  Future<void> bootApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pinServiceProvider.overrideWith((_) => fastPin())],
        child: const ChauffeurApp(),
      ),
    );
    // Opérations asynchrones réelles au démarrage (stockage, dérivation de clé
    // dans un isolate) : on leur laisse le temps avant la frame suivante.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('sans code configuré, l\'application demande la connexion',
      (tester) async {
    await bootApp(tester);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(PinLockPage), findsNothing);
  });

  testWidgets('une session ouverte sans code impose d\'en créer un',
      (tester) async {
    // Appareil connecté avant que le code devienne obligatoire : on ne le
    // laisse pas entrer dans l'application sans en installer un.
    storage.values['access_token'] = 'jeton-opaque';

    await bootApp(tester);
    SessionManager.instance.stop();

    expect(find.byType(PinSetupPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('l\'écran de verrouillage n\'expose aucune identité',
      (tester) async {
    // Le compte du chauffeur EST son numéro : il ne doit pas apparaître. Le
    // prénom non plus — l'écran verrouillé se contente de demander le code.
    await tester.runAsync(() => fastPin().configure(
          code: '48213',
          refreshToken: 'refresh-token-abc',
          account: '+2250708090910',
          displayName: 'Abou-dramane',
        ));

    await bootApp(tester);

    expect(find.byType(PinLockPage), findsOneWidget);
    expect(find.textContaining('0708090910'), findsNothing);
    expect(find.textContaining('Abou-dramane'), findsNothing);
  });

  testWidgets('un code erroné décompte les essais sans quitter l\'écran',
      (tester) async {
    await tester.runAsync(() => fastPin().configure(
          code: '48213',
          refreshToken: 'refresh-token-abc',
          account: '+2250708090910',
          displayName: 'Abou-dramane',
        ));

    await bootApp(tester);

    for (final digit in '90427'.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();

    expect(find.text('Code incorrect. 4 essais restants.'), findsOneWidget);
    expect(find.byType(PinLockPage), findsOneWidget);
  });
}
