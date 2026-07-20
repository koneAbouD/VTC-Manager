import '../../../../core/network/api_client.dart';
import '../../domain/entities/statut_vehicule.dart';

class ReferentielItem {
  final int id;
  final String nom;
  const ReferentielItem({required this.id, required this.nom});

  factory ReferentielItem.fromJson(Map<String, dynamic> json) =>
      ReferentielItem(
        id: json['id'] as int,
        nom: (json['nom'] ?? json['libelle'] ?? json['name'] ?? '').toString(),
      );

  @override
  bool operator ==(Object other) => other is ReferentielItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class ReferentielDatasource {
  final ApiClient _api;
  const ReferentielDatasource(this._api);

  // Sélection dans les formulaires : on ne veut que les référentiels ACTIFS.
  // Le paramétrage, lui, liste tout via le module générique.
  Future<List<ReferentielItem>> getTypesVehicules() async {
    final data = await _api.get('/v1/types-vehicules/actifs') as List;
    return data
        .map((e) => ReferentielItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReferentielItem>> getTypesActivites() async {
    final data = await _api.get('/v1/types-activites/actifs') as List;
    return data
        .map((e) => ReferentielItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReferentielItem>> getMarquesByType(int typeId) async {
    final data =
        await _api.get('/v1/marques/by-type/$typeId') as List;
    return data
        .map((e) => ReferentielItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReferentielItem>> getModelesByTypeAndMarque(
      int typeId, int marqueId) async {
    final data = await _api.get(
      '/v1/modeles/by-type-and-marque',
      query: {'typeId': '$typeId', 'marqueId': '$marqueId'},
    ) as List;
    return data
        .map((e) => ReferentielItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReferentielItem>> getGroupes() async {
    final data = await _api.get('/v1/groupes') as List;
    return data
        .map((e) => ReferentielItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<StatutVehicule>> getStatutsVehicule() async {
    final data = await _api.get('/v1/statuts-vehicule') as List;
    return data
        .map((e) => StatutVehicule.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
