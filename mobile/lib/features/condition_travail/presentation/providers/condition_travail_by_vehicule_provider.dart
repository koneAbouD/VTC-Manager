import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../pages/condition_travail_models.dart';

final _ctvSecureStorage =
    Provider<SecureStorage>((_) => const SecureStorage());

final _ctvApiClient = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_ctvSecureStorage)));

/// Renvoie la condition de travail liée à un véhicule, ou null si aucune
/// condition n'est attachée. La condition est la source unique pour les
/// détails de recettes, cotisations et pénalités du véhicule.
final conditionTravailByVehiculeIdProvider =
    FutureProvider.family<ConditionTravailLocal?, int>((ref, vehiculeId) async {
  final client = ref.watch(_ctvApiClient);
  final data = await client.get('/vehicules/$vehiculeId/condition-travail');
  if (data == null) return null; // 204 No Content : pas de condition liée
  return ConditionTravailLocal.fromJson(data as Map<String, dynamic>);
});
