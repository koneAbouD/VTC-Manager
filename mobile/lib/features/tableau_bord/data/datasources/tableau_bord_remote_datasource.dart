import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/tableau_bord_model.dart';

class TableauBordRemoteDatasource {
  final ApiClient _client;
  const TableauBordRemoteDatasource(this._client);

  /// Photo complète de la période — quatre blocs en un appel, pour qu'ils
  /// parlent tous du même instant. Sans [annee]/[mois], le backend sert le
  /// mois courant.
  Future<TableauBordModel> getTableauBord({
    int? annee,
    int? mois,
    String base = 'CAISSE',
    int? groupeId,
    int? activiteId,
  }) async {
    final data = await _client.get('/tableau-bord',
        query: requete(annee, mois, base, groupeId, activiteId));
    if (data is! Map<String, dynamic>) {
      throw const ApiException(500, 'Format de réponse inattendu');
    }
    return TableauBordModel.fromJson(data);
  }

  /// Dernière photo reçue pour ce cadrage, à afficher en attendant le
  /// serveur (`null` si rien n'est en cache).
  Future<TableauBordModel?> getTableauBordEnCache({
    int? annee,
    int? mois,
    String base = 'CAISSE',
    int? groupeId,
    int? activiteId,
  }) async {
    final data = await _client.lireCache('/tableau-bord',
        query: requete(annee, mois, base, groupeId, activiteId));
    return data is Map<String, dynamic> ? TableauBordModel.fromJson(data) : null;
  }

  /// Paramètres de `GET /tableau-bord` : la même requête doit donner la même
  /// URL, sans quoi le cache ne la retrouve pas (lecture et préchargement).
  static Map<String, String> requete(
    int? annee,
    int? mois,
    String base,
    int? groupeId,
    int? activiteId,
  ) =>
      {
        if (annee != null) 'annee': '$annee',
        if (mois != null) 'mois': '$mois',
        'base': base,
        if (groupeId != null) 'groupeId': '$groupeId',
        if (activiteId != null) 'activiteId': '$activiteId',
      };
}
