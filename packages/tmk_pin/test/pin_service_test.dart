import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_pin/tmk_pin.dart';

void main() {
  // Le facteur de travail PBKDF2 n'a rien à prouver ici : on l'abaisse pour
  // garder la suite rapide. Le défaut de production est dans [PinCipher].
  const iterations = 1000;

  late InMemoryKeyValueStore raw;
  late PinService service;

  PinService build() => PinService(PinStore(raw), iterations: iterations);

  setUp(() {
    raw = InMemoryKeyValueStore();
    service = build();
  });

  Future<void> configure({String code = '48213'}) => service.configure(
        code: code,
        refreshToken: 'refresh-token-abc',
        account: 'gestionnaire',
        displayName: 'Abou-dramane',
      );

  group('configuration', () {
    test('aucun code au départ', () async {
      expect(await service.isConfigured(), isFalse);
      expect(service.isUnlocked, isFalse);
    });

    test('configurer installe le coffre et ouvre la session', () async {
      await configure();
      expect(await service.isConfigured(), isTrue);
      expect(service.isUnlocked, isTrue);
      expect(await service.displayName(), 'Abou-dramane');
      expect(await service.account(), 'gestionnaire');
    });

    test('le refresh token n\'apparaît en clair nulle part', () async {
      await configure();
      expect(
        raw.values.values.any((v) => v.contains('refresh-token-abc')),
        isFalse,
        reason: 'le coffre doit être chiffré',
      );
    });

    test('deux appareils, même code : sels et coffres différents', () async {
      await configure();
      final premier = Map<String, String>.from(raw.values);

      raw = InMemoryKeyValueStore();
      service = build();
      await configure();

      expect(raw.values['pin_salt'], isNot(premier['pin_salt']));
      expect(raw.values['pin_cipher'], isNot(premier['pin_cipher']));
    });
  });

  group('déverrouillage', () {
    test('le bon code restitue le refresh token', () async {
      await configure();
      service.lock();
      expect(service.isUnlocked, isFalse);

      final result = await service.unlock('48213');
      expect(result, isA<UnlockSuccess>());
      expect((result as UnlockSuccess).refreshToken, 'refresh-token-abc');
      expect(service.isUnlocked, isTrue);
    });

    test('un mauvais code décompte les essais sans rien révéler', () async {
      await configure();
      service.lock();

      final result = await service.unlock('11111');
      expect(result, isA<UnlockFailure>());
      expect((result as UnlockFailure).remainingAttempts,
          PinService.maxAttempts - 1);
      expect(service.isUnlocked, isFalse);
    });

    test('un essai réussi remet le compteur à zéro', () async {
      await configure();
      service.lock();

      await service.unlock('00000');
      await service.unlock('48213');

      final result = await service.unlock('00000') as UnlockFailure;
      expect(result.remainingAttempts, PinService.maxAttempts - 1);
    });

    test('le compteur survit au redémarrage de l\'application', () async {
      await configure();
      await service.unlock('00000');
      await service.unlock('00000');

      // Nouvelle instance sur le même stockage : l'app a été relancée.
      final apresRedemarrage = build();
      final result = await apresRedemarrage.unlock('00000') as UnlockFailure;
      expect(result.remainingAttempts, PinService.maxAttempts - 3);
    });

    test('essais épuisés : purge complète et retour au login', () async {
      await configure();

      UnlockResult? dernier;
      for (var i = 0; i < PinService.maxAttempts; i++) {
        await raw.write('pin_locked_until', '0'); // on saute la temporisation
        dernier = await service.unlock('00000');
      }

      expect(dernier, isA<UnlockExhausted>());
      expect(await service.isConfigured(), isFalse);
      expect(raw.values, isEmpty);
    });

    test('la temporisation refuse l\'essai sans le compter', () async {
      await configure();
      for (var i = 0; i < 3; i++) {
        await raw.write('pin_locked_until', '0');
        await service.unlock('00000');
      }

      // Le 3e échec arme la temporisation : l'essai suivant est repoussé.
      final result = await service.unlock('48213');
      expect(result, isA<UnlockThrottled>());
      expect((result as UnlockThrottled).remaining.inSeconds, lessThanOrEqualTo(5));
      expect(await service.throttleRemaining(), isNotNull);
    });
  });

  group('cycle de vie de la session', () {
    test('le token renouvelé est rechiffré tant que la session est ouverte',
        () async {
      await configure();
      expect(await service.updateRefreshToken('refresh-token-2'), isTrue);

      service.lock();
      final result = await service.unlock('48213') as UnlockSuccess;
      expect(result.refreshToken, 'refresh-token-2');
    });

    test('verrouillé, le rechiffrement est refusé et le coffre intact',
        () async {
      await configure();
      service.lock();

      expect(await service.updateRefreshToken('refresh-token-2'), isFalse);
      final result = await service.unlock('48213') as UnlockSuccess;
      expect(result.refreshToken, 'refresh-token-abc');
    });

    test('changer de code conserve la session', () async {
      await configure();
      expect(
        await service.changeCode(currentCode: '48213', newCode: '90427'),
        isTrue,
      );

      service.lock();
      expect(await service.unlock('48213'), isA<UnlockFailure>());
      final result = await service.unlock('90427') as UnlockSuccess;
      expect(result.refreshToken, 'refresh-token-abc');
    });

    test('changer de code échoue si l\'ancien est faux', () async {
      await configure();
      expect(
        await service.changeCode(currentCode: '00000', newCode: '90427'),
        isFalse,
      );
      service.lock();
      expect(await service.unlock('48213'), isA<UnlockSuccess>());
    });

    test('une connexion sous un autre compte purge le code', () async {
      await configure();
      expect(await service.resetIfOtherAccount('gestionnaire'), isFalse);
      expect(await service.resetIfOtherAccount('autre-compte'), isTrue);
      expect(await service.isConfigured(), isFalse);
    });
  });

  group('déverrouillage biométrique', () {
    test('désactivé tant qu\'on ne l\'a pas demandé', () async {
      await configure();
      expect(await service.isBiometricsEnabled(), isFalse);
      expect(await service.unlockWithBiometrics(), isNull);
    });

    test('activé, il rouvre le coffre sans le code', () async {
      await configure();
      expect(await service.enableBiometrics(), isTrue);

      service.lock();
      final result = await service.unlockWithBiometrics();
      expect(result, isA<UnlockSuccess>());
      expect((result! as UnlockSuccess).refreshToken, 'refresh-token-abc');
      expect(service.isUnlocked, isTrue);
    });

    test('l\'activation exige une session déverrouillée', () async {
      await configure();
      service.lock();
      expect(await service.enableBiometrics(), isFalse);
      expect(await service.isBiometricsEnabled(), isFalse);
    });

    test('la clé rangée ne laisse pas fuiter le code ni le token', () async {
      await configure();
      await service.enableBiometrics();

      expect(raw.values.values.any((v) => v.contains('48213')), isFalse);
      expect(
        raw.values.values.any((v) => v.contains('refresh-token-abc')),
        isFalse,
      );
    });

    test('désactiver efface la clé sans toucher au coffre', () async {
      await configure();
      await service.enableBiometrics();
      await service.disableBiometrics();

      expect(await service.isBiometricsEnabled(), isFalse);
      expect(await service.unlockWithBiometrics(), isNull);

      service.lock();
      expect(await service.unlock('48213'), isA<UnlockSuccess>());
    });

    test('il survit au redémarrage de l\'application', () async {
      await configure();
      await service.enableBiometrics();

      final apresRedemarrage = build();
      expect(await apresRedemarrage.isBiometricsEnabled(), isTrue);
      expect(await apresRedemarrage.unlockWithBiometrics(),
          isA<UnlockSuccess>());
    });

    test('la temporisation des échecs de code lui est opposable', () async {
      await configure();
      await service.enableBiometrics();
      for (var i = 0; i < 3; i++) {
        await raw.write('pin_locked_until', '0');
        await service.unlock('00000');
      }

      expect(await service.unlockWithBiometrics(), isA<UnlockThrottled>());
    });

    test('changer de code réinstalle la clé au lieu de la perdre', () async {
      await configure();
      await service.enableBiometrics();

      await service.changeCode(currentCode: '48213', newCode: '90427');
      expect(await service.isBiometricsEnabled(), isTrue);

      service.lock();
      final result = await service.unlockWithBiometrics();
      expect((result! as UnlockSuccess).refreshToken, 'refresh-token-abc');
    });

    test('changer de code sans biométrie n\'en active pas', () async {
      await configure();
      await service.changeCode(currentCode: '48213', newCode: '90427');
      expect(await service.isBiometricsEnabled(), isFalse);
    });

    test('une clé qui n\'ouvre plus le coffre est abandonnée', () async {
      await configure();
      await service.enableBiometrics();
      // Coffre réécrit avec un sel neuf, hors de tout appel à [configure].
      await raw.write('pin_cipher', raw.values['pin_cipher']!.substring(4));

      expect(await service.unlockWithBiometrics(), isNull);
      expect(await service.isBiometricsEnabled(), isFalse);
    });

    test('la purge du code emporte la clé biométrique', () async {
      await configure();
      await service.enableBiometrics();
      await service.markBiometricsProposed();

      await service.reset();
      expect(await service.isBiometricsEnabled(), isFalse);
      expect(await service.hasProposedBiometrics(), isFalse);
      expect(raw.values, isEmpty);
    });

    test('la proposition ne se fait qu\'une fois', () async {
      await configure();
      expect(await service.hasProposedBiometrics(), isFalse);
      await service.markBiometricsProposed();
      expect(await build().hasProposedBiometrics(), isTrue);
    });
  });

  group('validation du code', () {
    test('refuse les codes trop courts ou non numériques', () {
      expect(PinService.validate('123'), isNotNull);
      expect(PinService.validate('12a45'), isNotNull);
    });

    test('refuse les codes devinables', () {
      expect(PinService.validate('00000'), isNotNull);
      expect(PinService.validate('11111'), isNotNull);
      expect(PinService.validate('12345'), isNotNull);
      expect(PinService.validate('54321'), isNotNull);
    });

    test('accepte un code ordinaire', () {
      expect(PinService.validate('48213'), isNull);
      expect(PinService.validate('90427'), isNull);
    });
  });
}
