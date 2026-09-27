import 'dart:typed_data';

import '../../../../core/network/api_client.dart';

class RecuRemoteDatasource {
  final ApiClient _client;
  const RecuRemoteDatasource(this._client);

  /// Le reçu des écritures données, en données — `GET /recus/501,502`.
  Future<Map<String, dynamic>> getRecu(List<int> operationIds) async =>
      await _client.get('/recus/${operationIds.join(',')}')
          as Map<String, dynamic>;

  /// Reçu PDF des écritures données — `GET /recus/501,502/pdf`.
  Future<Uint8List> getRecuPdf(List<int> operationIds) =>
      _client.getBytes('/recus/${operationIds.join(',')}/pdf');
}
