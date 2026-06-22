import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/categorie_operation_remote_datasource.dart';
import '../../data/repositories_impl/categorie_operation_repository_impl.dart';
import '../../domain/entities/categorie_operation.dart';
import '../../domain/entities/sous_categorie_operation.dart';
import '../../domain/enums/type_operation.dart';
import '../../domain/repositories/categorie_operation_repository.dart';
import '../../domain/usecases/get_categories_operation_usecase.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────

final _catSecureStorage =
    Provider<SecureStorage>((_) => const SecureStorage());

final _catApiClient = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_catSecureStorage)));

final _catDatasourceProvider =
    Provider<CategorieOperationRemoteDatasource>((ref) =>
        CategorieOperationRemoteDatasource(ref.watch(_catApiClient)));

final categorieOperationRepositoryProvider =
    Provider<CategorieOperationRepository>((ref) =>
        CategorieOperationRepositoryImpl(ref.watch(_catDatasourceProvider)));

final _getCatUCProvider = Provider((ref) =>
    GetCategoriesOperationUseCase(
        ref.watch(categorieOperationRepositoryProvider)));

// ── Providers FutureProvider ───────────────────────────────────────────────

/// Toutes les catégories (tous types confondus)
final allCategoriesProvider =
    FutureProvider<List<CategorieOperation>>((ref) async {
  final uc = ref.watch(_getCatUCProvider);
  final result = await uc();
  return result.fold((f) => throw Exception(f.message), (list) => list);
});

/// Catégories filtrées par type, avec sous-catégorie imbriquée
final categoriesByTypeProvider = FutureProvider.family<
    List<CategorieOperation>, TypeOperation>((ref, type) async {
  final uc = ref.watch(_getCatUCProvider);
  final result = await uc(
      typeOperation: type.name, includeSousCategorie: true);
  return result.fold((f) => throw Exception(f.message), (list) => list);
});

/// Sous-catégories pour une catégorie donnée
final sousCategoriesProvider = FutureProvider.family<
    List<SousCategorieOperation>, int>((ref, categorieId) async {
  final uc = ref.watch(_getCatUCProvider);
  final result = await uc.getSousCategories(categorieId: categorieId);
  return result.fold((f) => throw Exception(f.message), (list) => list);
});
