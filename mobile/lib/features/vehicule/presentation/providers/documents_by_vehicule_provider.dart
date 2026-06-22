import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';

class DocumentVehiculeLocal {
  final int id;
  final String? typeNom;
  final String? reference;
  final DateTime? dateEmission;
  final DateTime? dateExpiration;
  final String? fichierNom;
  final String? fichierType;
  final String? statut;
  final bool permanent;

  const DocumentVehiculeLocal({
    required this.id,
    this.typeNom,
    this.reference,
    this.dateEmission,
    this.dateExpiration,
    this.fichierNom,
    this.fichierType,
    this.statut,
    this.permanent = false,
  });

  factory DocumentVehiculeLocal.fromJson(Map<String, dynamic> j) {
    final type = j['typeDocument'];
    String? typeNom;
    if (type is Map<String, dynamic>) {
      typeNom = (type['libelle'] ?? type['nom'] ?? type['code']) as String?;
    }
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v as String);
      } catch (_) {
        return null;
      }
    }

    return DocumentVehiculeLocal(
      id: j['id'] as int,
      typeNom: typeNom,
      reference: j['reference'] as String?,
      dateEmission: parseDate(j['dateEmission']),
      dateExpiration: parseDate(j['dateExpiration']),
      fichierNom: j['fichierNom'] as String?,
      fichierType: j['fichierType'] as String?,
      statut: j['statut'] as String?,
      permanent: (j['permanence'] as bool?) ?? false,
    );
  }

  String get displayName {
    final ref = (reference ?? '').trim();
    if (typeNom != null && typeNom!.isNotEmpty) {
      return ref.isEmpty ? typeNom! : '${typeNom!} – $ref';
    }
    return ref.isNotEmpty ? ref : (fichierNom ?? 'Document');
  }
}

final _docSecureStorage =
    Provider<SecureStorage>((_) => const SecureStorage());

final docApiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_docSecureStorage)));

final documentsByVehiculeIdProvider =
    FutureProvider.family<List<DocumentVehiculeLocal>, int>(
        (ref, vehiculeId) async {
  final client = ref.watch(docApiClientProvider);
  final data = await client.get('/v1/documents/vehicule/$vehiculeId');
  if (data == null) return [];
  return (data as List)
      .map((e) => DocumentVehiculeLocal.fromJson(e as Map<String, dynamic>))
      .where((d) => !(d.typeNom ?? '').toLowerCase().contains('photo'))
      .toList();
});
