import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../operation_financiere/domain/entities/categorie_operation.dart';
import '../../../operation_financiere/data/models/categorie_operation_model.dart';

final _tmSecureStorage = Provider<SecureStorage>((_) => const SecureStorage());
final _tmApiClient =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(_tmSecureStorage)));

/// Retourne les [CategorieOperation] dont la sous-catégorie a le libellé fourni.
/// Exemple : libelle = 'Maintenances' pour les types de maintenance.
final typeMaintenanceProvider =
    FutureProvider.family<List<CategorieOperation>, String>(
        (ref, sousCategorieLibelle) async {
  final client = ref.watch(_tmApiClient);
  final data = await client.get(
      '/categories-operation?sousCategorieLibelle=${Uri.encodeComponent(sousCategorieLibelle)}');
  if (data is! List) return [];
  return data
      .map((e) =>
          CategorieOperationModel.fromJson(e as Map<String, dynamic>))
      .toList();
});
