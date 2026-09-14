import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vtc_manager/core/error/exception.dart';
import 'package:vtc_manager/core/network/api_client.dart';
import 'package:vtc_manager/core/storage/secure_storage.dart';

/// Un téléchargement refusé — le reçu PDF d'une écriture annulée — doit rendre
/// le motif rédigé par le serveur, pas le JSON brut de sa réponse.
class _SansJeton extends SecureStorage {
  const _SansJeton();

  @override
  Future<String?> getAccessToken() async => null;
}

void main() {
  test('un refus métier rend le message du serveur, pas son JSON', () async {
    const motif = "L'écriture ENC-2026-000501 a été annulée : un reçu ne peut pas "
        'attester un versement qui ne compte plus.';
    final client = ApiClient(
      const _SansJeton(),
      MockClient((_) async => http.Response(
            '{"status":409,"error":"RECU_IMPOSSIBLE","message":"$motif"}',
            409,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );

    await expectLater(
      client.getBytes('/recus/501/pdf'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 409)
          .having((e) => e.message, 'message', motif)),
    );
  });

  test('une page HTML de proxy laisse place au message générique', () async {
    final client = ApiClient(
      const _SansJeton(),
      MockClient((_) async => http.Response('<html><body>Bad gateway</body></html>', 502)),
    );

    await expectLater(
      client.getBytes('/recus/501/pdf'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Erreur serveur (502).')),
    );
  });
}
