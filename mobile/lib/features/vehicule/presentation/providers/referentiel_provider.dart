import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/referentiel_datasource.dart';

// ── Infrastructure (réutilise les mêmes singletons) ────────────────────────

final _secureStorageProvider =
    Provider<SecureStorage>((_) => const SecureStorage());

final _apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(_secureStorageProvider)),
);

final _referentielDatasourceProvider = Provider<ReferentielDatasource>(
  (ref) => ReferentielDatasource(ref.watch(_apiClientProvider)),
);

// ── Providers de listes ────────────────────────────────────────────────────

final typesVehiculesProvider =
    FutureProvider<List<ReferentielItem>>((ref) async {
  return ref.watch(_referentielDatasourceProvider).getTypesVehicules();
});

final typesActivitesProvider =
    FutureProvider<List<ReferentielItem>>((ref) async {
  return ref.watch(_referentielDatasourceProvider).getTypesActivites();
});

// Marques filtrées par type de véhicule sélectionné
final marquesByTypeProvider =
    FutureProvider.family<List<ReferentielItem>, int>((ref, typeId) async {
  return ref.watch(_referentielDatasourceProvider).getMarquesByType(typeId);
});

// Modèles filtrés par type + marque
final modelesByTypeAndMarqueProvider =
    FutureProvider.family<List<ReferentielItem>, (int, int)>(
        (ref, args) async {
  final (typeId, marqueId) = args;
  return ref
      .watch(_referentielDatasourceProvider)
      .getModelesByTypeAndMarque(typeId, marqueId);
});

final groupesProvider =
    FutureProvider<List<ReferentielItem>>((ref) async {
  return ref.watch(_referentielDatasourceProvider).getGroupes();
});
