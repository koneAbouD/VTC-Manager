import 'dart:typed_data';

import '../../../../core/network/api_client.dart';

class RecuRemoteDatasource {
  final ApiClient _client;
  const RecuRemoteDatasource(this._client);

  /// Reçu PDF des écritures données — `GET /recus/501,502/pdf`.
  Future<Uint8List> getRecuPdf(List<int> operationIds) =>
      _client.getBytes('/recus/${operationIds.join(',')}/pdf');
}
