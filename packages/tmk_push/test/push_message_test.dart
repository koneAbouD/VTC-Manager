import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_push/tmk_push.dart';

void main() {
  group('PushMessage.depuisCharge', () {
    test('lit une charge utile complète', () {
      final message = PushMessage.depuisCharge(
        {
          'type': 'PENALITE_APPLIQUEE',
          'notificationId': '42',
          'entiteType': 'LIGNE_PENALITE',
          'entiteId': '4213',
        },
        titre: 'Nouvelle pénalité',
        corps: 'Une pénalité a été portée à votre compte.',
      );

      expect(message, isNotNull);
      expect(message!.type, 'PENALITE_APPLIQUEE');
      expect(message.notificationId, 42);
      expect(message.entiteType, 'LIGNE_PENALITE');
      expect(message.entiteId, 4213);
      expect(message.titre, 'Nouvelle pénalité');
      expect(message.ouvreUnEcran, isTrue);
    });

    test('accepte une notification sans cible à ouvrir', () {
      final message = PushMessage.depuisCharge({'type': 'TEST'});

      expect(message, isNotNull);
      expect(message!.ouvreUnEcran, isFalse);
      expect(message.entiteId, isNull);
    });

    test('rejette une charge sans type', () {
      // Les sondes de la console Firebase et les campagnes arrivent par le même
      // canal : sans type, il n'y a aucun écran à ouvrir.
      expect(PushMessage.depuisCharge({'entiteId': '1'}), isNull);
      expect(PushMessage.depuisCharge({'type': ''}), isNull);
      expect(PushMessage.depuisCharge(const {}), isNull);
    });

    test('tolère un identifiant illisible sans perdre le message', () {
      final message = PushMessage.depuisCharge({
        'type': 'MAINTENANCE_A_VENIR',
        'entiteType': 'MAINTENANCE',
        'entiteId': 'pas-un-nombre',
      });

      expect(message, isNotNull);
      expect(message!.entiteId, isNull);
      expect(message.ouvreUnEcran, isFalse);
    });

    test('accepte un entier déjà typé', () {
      // Selon la plateforme, le plugin rend la charge utile en String ou
      // dans son type d'origine.
      final message = PushMessage.depuisCharge({
        'type': 'TEST',
        'notificationId': 7,
        'entiteId': 9,
        'entiteType': 'ARRETE',
      });

      expect(message!.notificationId, 7);
      expect(message.entiteId, 9);
    });

    test('ignore un entiteType vide', () {
      final message = PushMessage.depuisCharge({
        'type': 'TEST',
        'entiteType': '',
        'entiteId': '3',
      });

      expect(message!.entiteType, isNull);
      expect(message.ouvreUnEcran, isFalse);
    });
  });
}
