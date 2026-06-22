import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';

class TypeDocument {
  final int id;
  final String nom;
  final bool obligatoire;

  const TypeDocument({
    required this.id,
    required this.nom,
    this.obligatoire = false,
  });

  factory TypeDocument.fromJson(Map<String, dynamic> j) => TypeDocument(
        id: j['id'] as int,
        nom: j['nom'] as String? ?? '',
        obligatoire: j['obligatoire'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) => other is TypeDocument && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final _typeDocSecureStorageProvider =
    Provider<SecureStorage>((_) => const SecureStorage());

final _typeDocApiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_typeDocSecureStorageProvider)));

/// Types de document applicables aux véhicules (GET /v1/types-document/cible/VEHICULE).
final typesDocVehiculeProvider =
    FutureProvider<List<TypeDocument>>((ref) async {
  final client = ref.watch(_typeDocApiClientProvider);
  final data = await client.get('/v1/types-document/cible/VEHICULE');
  if (data is! List) return [];
  return data
      .map((e) => TypeDocument.fromJson(e as Map<String, dynamic>))
      .toList();
});
