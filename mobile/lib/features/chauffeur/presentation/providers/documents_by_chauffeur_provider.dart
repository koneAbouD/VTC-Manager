import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';

class DocumentChauffeurLocal {
  final int id;
  final String? typeNom;
  final String? reference;
  final DateTime? dateEmission;
  final DateTime? dateExpiration;
  final String? fichierNom;
  final String? fichierType;
  final String? fichierUrl;
  final String? statut;

  /// Catégories de permis (ex: ["B", "C"]) — vide si non-permis.
  final List<String> categorie;

  /// true si le document n'a pas de date d'expiration.
  final bool permanent;

  const DocumentChauffeurLocal({
    required this.id,
    this.typeNom,
    this.reference,
    this.dateEmission,
    this.dateExpiration,
    this.fichierNom,
    this.fichierType,
    this.fichierUrl,
    this.statut,
    this.categorie = const [],
    this.permanent = false,
  });

  factory DocumentChauffeurLocal.fromJson(Map<String, dynamic> j) {
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

    // Parsing categorie (Set<TypePermis> sérialisé en liste de strings)
    final rawCat = j['categorie'];
    final categorie = rawCat is List
        ? rawCat.map((e) => e.toString()).toList()
        : const <String>[];

    return DocumentChauffeurLocal(
      id: j['id'] as int,
      typeNom: typeNom,
      reference: j['reference'] as String?,
      dateEmission: parseDate(j['dateEmission']),
      dateExpiration: parseDate(j['dateExpiration']),
      fichierNom: j['fichierNom'] as String?,
      fichierType: j['fichierType'] as String?,
      fichierUrl: j['fichierUrl'] as String?,
      statut: j['statut'] as String?,
      categorie: categorie,
      permanent: (j['permanence'] as bool?) ?? false,
    );
  }

  String get displayName {
    final ref = (reference ?? '').trim();
    if (typeNom != null && typeNom!.isNotEmpty) {
      return ref.isEmpty ? typeNom! : '$typeNom – $ref';
    }
    return ref.isNotEmpty ? ref : (fichierNom ?? 'Document');
  }
}

final _docChauffeurSecureStorage =
    Provider<SecureStorage>((_) => const SecureStorage());

final docChauffeurApiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_docChauffeurSecureStorage)));

final documentsByChauffeurIdProvider =
    FutureProvider.family<List<DocumentChauffeurLocal>, int>(
        (ref, chauffeurId) async {
  final client = ref.watch(docChauffeurApiClientProvider);
  final data = await client.get('/v1/documents/chauffeur/$chauffeurId');
  if (data == null) return [];
  return (data as List)
      .map((e) => DocumentChauffeurLocal.fromJson(e as Map<String, dynamic>))
      .toList();
});
