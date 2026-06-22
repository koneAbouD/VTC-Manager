import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../vehicule/presentation/providers/type_document_provider.dart';

final _typeDocChauffeurStorage =
    Provider<SecureStorage>((_) => const SecureStorage());

final _typeDocChauffeurApi = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_typeDocChauffeurStorage)));

/// Types de document applicables aux chauffeurs.
final typesDocChauffeurProvider =
    FutureProvider<List<TypeDocument>>((ref) async {
  final client = ref.watch(_typeDocChauffeurApi);
  final data = await client.get('/v1/types-document/cible/CHAUFFEUR');
  if (data is! List) return [];
  return data
      .map((e) => TypeDocument.fromJson(e as Map<String, dynamic>))
      .toList();
});
