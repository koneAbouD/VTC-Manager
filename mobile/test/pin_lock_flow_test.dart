import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_pin/tmk_pin.dart';
import 'package:vtc_manager/features/auth/presentation/pages/login_page.dart';
import 'package:vtc_manager/features/auth/presentation/pages/pin_lock_page.dart';
import 'package:vtc_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:vtc_manager/main.dart';

/// Le stockage sécurisé passe par un canal de plateforme : en test, on le
/// remplace par une simple map. C'est ce qui permet d'exercer le parcours réel
/// (coffre chiffré compris) sans Keychain ni Keystore.
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

  // Facteur de travail abaissé : la robustesse du PBKDF2 est vérifiée dans le
  // paquet `tmk_pin`, ici on veut un test rapide.
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
        child: const VtcManagerApp(),
      ),
    );
    // Le démarrage enchaîne des opérations asynchrones réelles (lecture du
    // stockage, dérivation de clé dans un isolate) : on leur laisse le temps de
    // s'exécuter avant de peindre la frame suivante.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> tapCode(WidgetTester tester, String code) async {
    for (final digit in code.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
  }

  testWidgets('sans code configuré, l\'application demande la connexion',
      (tester) async {
    await bootApp(tester);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(PinLockPage), findsNothing);
  });

  testWidgets(
      'avec un code configuré, l\'écran d\'accès demande le code sans '
      'nommer personne', (tester) async {
    await tester.runAsync(() => fastPin().configure(
          code: '48213',
          refreshToken: 'refresh-token-abc',
          account: 'akone',
          displayName: 'Abou-dramane',
        ));

    await bootApp(tester);

    expect(find.byType(PinLockPage), findsOneWidget);
    // Ni salutation, ni identité : l'écran verrouillé n'expose rien.
    expect(find.textContaining('Abou-dramane'), findsNothing);
    expect(find.textContaining('akone'), findsNothing);
    expect(find.text('Veuillez saisir votre code TMK'), findsOneWidget);
    // Le pavé numérique, pas le clavier système.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('un code erroné décompte les essais sans quitter l\'écran',
      (tester) async {
    await tester.runAsync(() => fastPin().configure(
          code: '48213',
          refreshToken: 'refresh-token-abc',
          account: 'akone',
          displayName: 'Abou-dramane',
        ));

    await bootApp(tester);
    await tapCode(tester, '90427');

    expect(find.text('Code incorrect. 4 essais restants.'), findsOneWidget);
    expect(find.byType(PinLockPage), findsOneWidget);
  });

  testWidgets('le refresh token n\'est jamais stocké en clair', (tester) async {
    await tester.runAsync(() => fastPin().configure(
          code: '48213',
          refreshToken: 'refresh-token-abc',
          account: 'akone',
          displayName: 'Abou-dramane',
        ));

    await bootApp(tester);

    expect(
      storage.values.values.any((v) => v.contains('refresh-token-abc')),
      isFalse,
    );
  });
}
