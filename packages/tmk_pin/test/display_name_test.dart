import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_pin/tmk_pin.dart';

/// Fabrique un JWT non signé — seul le payload est lu.
String fakeJwt(Map<String, dynamic> claims) {
  String segment(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  return '${segment({'alg': 'none'})}.${segment(claims)}.signature';
}

void main() {
  group('JwtClaims', () {
    test('lit le prénom et l\'identifiant', () {
      final claims = JwtClaims.parse(fakeJwt({
        'given_name': 'Abou-dramane',
        'preferred_username': '+2250708090910',
      }));
      expect(claims.givenName, 'Abou-dramane');
      expect(claims.preferredUsername, '+2250708090910');
    });

    test('ne casse pas sur un jeton illisible', () {
      expect(JwtClaims.parse(null).values, isEmpty);
      expect(JwtClaims.parse('pas-un-jwt').values, isEmpty);
      expect(JwtClaims.parse('a.b.c').values, isEmpty);
    });

    test('traite une revendication vide comme absente', () {
      final claims = JwtClaims.parse(fakeJwt({'given_name': '   '}));
      expect(claims.givenName, isNull);
    });
  });

  group('DisplayName', () {
    test('le prénom métier prime sur le jeton', () {
      final name = DisplayName.resolve(
        profileFirstName: 'Abou-dramane',
        accessToken: fakeJwt({'given_name': 'Abou'}),
      );
      expect(name, 'Abou-dramane');
    });

    test('à défaut, le given_name du jeton', () {
      final name = DisplayName.resolve(
        accessToken: fakeJwt({
          'given_name': 'Abou-dramane',
          'preferred_username': '+2250708090910',
        }),
      );
      expect(name, 'Abou-dramane');
    });

    test('n\'affiche jamais un identifiant qui est un numéro de téléphone', () {
      // Cas de l'application chauffeur : le username EST le téléphone.
      for (final username in const [
        '+2250708090910',
        '0708090910',
        '07 08 09 09 10',
        '225-07-08-09-09',
      ]) {
        final name = DisplayName.resolve(
          accessToken: fakeJwt({'preferred_username': username}),
        );
        expect(name, isNull, reason: '$username ne doit pas être affiché');
      }
    });

    test('accepte un identifiant qui est un vrai nom d\'utilisateur', () {
      final name = DisplayName.resolve(
        accessToken: fakeJwt({'preferred_username': 'akone'}),
      );
      expect(name, 'akone');
    });

    test('retourne null quand rien n\'est exploitable', () {
      expect(DisplayName.resolve(accessToken: null), isNull);
      expect(DisplayName.resolve(accessToken: fakeJwt({})), isNull);
    });
  });
}
