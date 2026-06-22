import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../pages/condition_travail_models.dart';

final _penSecureStorageProvider =
    Provider<SecureStorage>((_) => const SecureStorage());

final _penApiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(_penSecureStorageProvider)),
);

final penalitesByVehiculeIdProvider =
    FutureProvider.family<List<PenaliteLocal>, int>((ref, vehiculeId) async {
  final client = ref.watch(_penApiClientProvider);
  final data = await client.get('/vehicules/$vehiculeId/penalites');
  return (data as List)
      .map((e) => PenaliteLocal.fromJson(e as Map<String, dynamic>))
      .toList();
});