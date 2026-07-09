import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/contravention_remote_datasource.dart';
import '../../data/models/apercu_import_model.dart';
import '../../data/models/contravention_model.dart';
import '../../data/repositories_impl/contravention_repository_impl.dart';
import '../../domain/entities/contravention.dart';
import '../../domain/repositories/contravention_repository.dart';
import '../../domain/usecases/create_contravention_usecase.dart';
import '../../domain/usecases/delete_contravention_usecase.dart';
import '../../domain/usecases/get_contraventions_usecase.dart';
import '../../domain/usecases/pay_contravention_usecase.dart';
import '../../domain/usecases/update_contravention_usecase.dart';
import 'contravention_state.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────

final _secureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(),
);

final _apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(_secureStorageProvider)),
);

// ── Datasource → Repository ─────────────────────────────────────────────────

final _contraventionDatasourceProvider =
    Provider<ContraventionRemoteDatasource>(
  (ref) => ContraventionRemoteDatasource(ref.watch(_apiClientProvider)),
);

final contraventionRepositoryProvider = Provider<ContraventionRepository>(
  (ref) =>
      ContraventionRepositoryImpl(ref.watch(_contraventionDatasourceProvider)),
);

// ── Use cases ───────────────────────────────────────────────────────────────

final _getContraventionsUseCaseProvider = Provider(
  (ref) =>
      GetContraventionsUseCase(ref.watch(contraventionRepositoryProvider)),
);
final _createContraventionUseCaseProvider = Provider(
  (ref) =>
      CreateContraventionUseCase(ref.watch(contraventionRepositoryProvider)),
);
final _updateContraventionUseCaseProvider = Provider(
  (ref) =>
      UpdateContraventionUseCase(ref.watch(contraventionRepositoryProvider)),
);
final _deleteContraventionUseCaseProvider = Provider(
  (ref) =>
      DeleteContraventionUseCase(ref.watch(contraventionRepositoryProvider)),
);
final _payContraventionUseCaseProvider = Provider(
  (ref) =>
      PayContraventionUseCase(ref.watch(contraventionRepositoryProvider)),
);

// ── Notifier ────────────────────────────────────────────────────────────────

class ContraventionNotifier extends StateNotifier<ContraventionState> {
  final GetContraventionsUseCase _getContraventions;
  final CreateContraventionUseCase _createContravention;
  final UpdateContraventionUseCase _updateContravention;
  final DeleteContraventionUseCase _deleteContravention;
  final PayContraventionUseCase _payContravention;

  ContraventionNotifier({
    required GetContraventionsUseCase getContraventions,
    required CreateContraventionUseCase createContravention,
    required UpdateContraventionUseCase updateContravention,
    required DeleteContraventionUseCase deleteContravention,
    required PayContraventionUseCase payContravention,
  })  : _getContraventions = getContraventions,
        _createContravention = createContravention,
        _updateContravention = updateContravention,
        _deleteContravention = deleteContravention,
        _payContravention = payContravention,
        super(const ContraventionInitial());

  Future<void> loadContraventions() async {
    state = const ContraventionLoading();
    final result = await _getContraventions.call();
    result.fold(
      (failure) => state = ContraventionError(failure.message),
      (contraventions) => state = ContraventionLoaded(contraventions),
    );
  }

  Future<String?> createContravention(Contravention contravention) async {
    final result = await _createContravention.call(contravention);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadContraventions();
        return null;
      },
    );
  }

  Future<String?> updateContravention(
      int id, Contravention contravention) async {
    final result = await _updateContravention.call(id, contravention);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadContraventions();
        return null;
      },
    );
  }

  Future<String?> deleteContravention(int id) async {
    final result = await _deleteContravention.call(id);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadContraventions();
        return null;
      },
    );
  }

  Future<String?> payContravention(int id, double montantPaye) async {
    final result = await _payContravention.call(id, montantPaye);
    return result.fold(
      (failure) => failure.message,
      (_) {
        loadContraventions();
        return null;
      },
    );
  }
}

// ── Liste paginée (scroll infini) pour la page Contraventions ────────────────

final contraventionsListeProvider = StateNotifierProvider.autoDispose<
    PagedListNotifier<Contravention>, PagedListState<Contravention>>(
  (ref) => PagedListNotifier<Contravention>(),
);

final contraventionNotifierProvider =
    StateNotifierProvider<ContraventionNotifier, ContraventionState>((ref) {
  return ContraventionNotifier(
    getContraventions: ref.watch(_getContraventionsUseCaseProvider),
    createContravention: ref.watch(_createContraventionUseCaseProvider),
    updateContravention: ref.watch(_updateContraventionUseCaseProvider),
    deleteContravention: ref.watch(_deleteContraventionUseCaseProvider),
    payContravention: ref.watch(_payContraventionUseCaseProvider),
  );
});

// ── Import PDF (Mode 1) ──────────────────────────────────────────────────────

/// Contrôleur léger pour le flux d'import : upload + aperçu puis confirmation.
/// Les pages gèrent leur propre état (chargement/erreur) autour de ces appels.
class ContraventionImportController {
  final ContraventionRemoteDatasource _datasource;
  const ContraventionImportController(this._datasource);

  Future<ApercuImportModel> importer(Uint8List pdfBytes, String filename) =>
      _datasource.importerReleve(pdfBytes, filename);

  Future<Map<String, dynamic>> confirmer(List<ContraventionModel> items) =>
      _datasource.confirmerImport(items);
}

final contraventionImportProvider = Provider<ContraventionImportController>(
  (ref) =>
      ContraventionImportController(ref.watch(_contraventionDatasourceProvider)),
);
