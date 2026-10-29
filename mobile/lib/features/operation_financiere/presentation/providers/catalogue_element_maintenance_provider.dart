import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/catalogue_element_maintenance_remote_datasource.dart';
import '../../data/repositories_impl/catalogue_element_maintenance_repository_impl.dart';
import '../../domain/entities/catalogue_element_maintenance.dart';
import '../../domain/repositories/catalogue_element_maintenance_repository.dart';
import '../../domain/usecases/get_catalogue_elements_maintenance_usecase.dart';

final _cemStorage = Provider<SecureStorage>((_) => const SecureStorage());
final _cemApiClient =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(_cemStorage)));

final _cemDatasourceProvider =
    Provider<CatalogueElementMaintenanceRemoteDatasource>((ref) =>
        CatalogueElementMaintenanceRemoteDatasource(
            ref.watch(_cemApiClient)));

final catalogueElementMaintenanceRepositoryProvider =
    Provider<CatalogueElementMaintenanceRepository>((ref) =>
        CatalogueElementMaintenanceRepositoryImpl(
            ref.watch(_cemDatasourceProvider)));

final _cemUCProvider = Provider((ref) =>
    GetCatalogueElementsMaintenanceUseCase(
        ref.watch(catalogueElementMaintenanceRepositoryProvider)));

/// Ce qui restreint les éléments proposés : le véhicule (sa marque et son
/// modèle) et le type de maintenance. `null` = pas de restriction.
typedef FiltreCatalogueMaintenance = ({int? vehiculeId, int? categorieTypeId});

/// Éléments actifs du catalogue, restreints à ceux compatibles avec le
/// véhicule (marque / modèle) et avec le type de maintenance (communs ou
/// réservés à ce type).
final catalogueElementsMaintenanceProvider = FutureProvider.family<
    List<CatalogueElementMaintenance>,
    FiltreCatalogueMaintenance>((ref, filtre) async {
  final uc = ref.watch(_cemUCProvider);
  final result = await uc(
      vehiculeId: filtre.vehiculeId, categorieTypeId: filtre.categorieTypeId);
  return result.fold((f) => throw Exception(f.message), (list) => list);
});
