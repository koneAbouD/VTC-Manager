import 'dart:typed_data';

import '../../../core/network/api_client.dart';

/// Description d'un champ d'un référentiel (issue du meta-catalogue backend).
class ChampDescriptor {
  final String nom;
  final String label;
  final String type; // text | number | bool | color | date | reference | enum
  final bool obligatoire;
  final bool editable;
  final String? refKey; // pour type=reference : clé du référentiel source
  final List<String> options; // pour type=enum

  const ChampDescriptor({
    required this.nom,
    required this.label,
    required this.type,
    required this.obligatoire,
    required this.editable,
    this.refKey,
    this.options = const [],
  });

  factory ChampDescriptor.fromJson(Map<String, dynamic> j) => ChampDescriptor(
        nom: j['nom'] as String,
        label: j['label'] as String? ?? j['nom'] as String,
        type: j['type'] as String? ?? 'text',
        obligatoire: j['obligatoire'] as bool? ?? false,
        editable: j['editable'] as bool? ?? true,
        refKey: j['refKey'] as String?,
        options: (j['options'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );

  bool get isActif => nom == 'actif';
}

/// Description d'un référentiel paramétrable (issue du meta-catalogue backend).
class ReferentielDescriptor {
  final String key;
  final String libelle;
  final String description;
  final String endpoint; // chemin complet, ex. « /api/v1/types-vehicules »
  final bool editable;
  final String idField; // « id » ou « code »
  final List<ChampDescriptor> champs;

  const ReferentielDescriptor({
    required this.key,
    required this.libelle,
    required this.description,
    required this.endpoint,
    required this.editable,
    required this.idField,
    required this.champs,
  });

  factory ReferentielDescriptor.fromJson(Map<String, dynamic> j) =>
      ReferentielDescriptor(
        key: j['key'] as String,
        libelle: j['libelle'] as String? ?? j['key'] as String,
        description: j['description'] as String? ?? '',
        endpoint: j['endpoint'] as String,
        editable: j['editable'] as bool? ?? false,
        idField: j['idField'] as String? ?? 'id',
        champs: (j['champs'] as List? ?? const [])
            .map((e) => ChampDescriptor.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Champs éditables hors drapeau « actif ».
  List<ChampDescriptor> get champsSaisis =>
      champs.where((c) => !c.isActif).toList();

  /// Champ servant de titre dans les listes (premier champ texte/reference).
  ChampDescriptor? get champTitre => champsSaisis.isNotEmpty
      ? champsSaisis.firstWhere(
          (c) => c.type == 'text' || c.type == 'reference',
          orElse: () => champsSaisis.first,
        )
      : null;

  bool get gereActif => champs.any((c) => c.isActif);
}

/// Accès REST générique aux données de référence et au meta-catalogue.
///
/// Les endpoints du catalogue sont des chemins complets préfixés « /api » ; le
/// client réseau ayant déjà « /api » dans sa base URL, on retire ce préfixe.
class ParametrageApi {
  final ApiClient _client;

  const ParametrageApi(this._client);

  static String _p(String endpoint) =>
      endpoint.startsWith('/api') ? endpoint.substring(4) : endpoint;

  Future<List<ReferentielDescriptor>> catalogue() async {
    final res = await _client.get('/v1/parametrage/catalogue');
    return (res as List<dynamic>)
        .map((e) => ReferentielDescriptor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> lister(String endpoint) async {
    final res = await _client.get(_p(endpoint));
    return (res as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> creer(
      String endpoint, Map<String, dynamic> body) async {
    final res = await _client.post(_p(endpoint), body);
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> mettreAJour(
      String endpoint, Object id, Map<String, dynamic> body) async {
    final res = await _client.put('${_p(endpoint)}/$id', body);
    return res as Map<String, dynamic>;
  }

  Future<void> changerActivation(String endpoint, Object id, bool actif) =>
      _client.patch('${_p(endpoint)}/$id/actif', {'actif': actif});

  Future<void> supprimer(String endpoint, Object id) =>
      _client.delete('${_p(endpoint)}/$id');

  /// Upload d'une image pour un champ de type `image` : envoie le fichier à
  /// `{endpoint}/image` (multipart) et retourne le nom d'objet (à enregistrer
  /// dans le champ) + une URL présignée d'aperçu.
  Future<({String image, String url})> uploaderImage(
      String endpoint, Uint8List bytes, String filename) async {
    final res = await _client.postFile('${_p(endpoint)}/image',
        bytes: bytes, filename: filename);
    final m = res as Map<String, dynamic>;
    return (image: m['image'] as String, url: m['url'] as String);
  }
}
