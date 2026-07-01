import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/operation_financiere.dart';
import '../../domain/usecases/get_operations_financieres_page_usecase.dart';
import 'operation_financiere_provider.dart';

/// État de la liste paginée (scroll infini) de la page Opérations.
class OperationsListeState {
  final List<OperationFinanciere> items;
  final bool initialLoading; // premier chargement / rechargement filtre
  final bool loadingMore; // chargement de la page suivante
  final bool hasMore; // reste-t-il des pages à charger ?
  final String? error;

  const OperationsListeState({
    this.items = const [],
    this.initialLoading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
  });

  OperationsListeState copyWith({
    List<OperationFinanciere>? items,
    bool? initialLoading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return OperationsListeState(
      items: items ?? this.items,
      initialLoading: initialLoading ?? this.initialLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OperationsListeNotifier extends StateNotifier<OperationsListeState> {
  final GetOperationsFinancieresPageUseCase _getPage;
  static const int _pageSize = 20;

  int _page = 0;

  // Filtres courants (mémorisés pour loadMore / refresh).
  String? _typeOperation;
  String? _debut;
  String? _fin;
  String? _statut;
  String? _categorieCode;
  String? _sousCategorieLibelle;
  int? _vehiculeId;
  int? _chauffeurId;
  String? _recherche;

  OperationsListeNotifier(this._getPage)
      : super(const OperationsListeState());

  /// (Re)charge la liste depuis la page 0 avec les filtres fournis.
  Future<void> load({
    String? typeOperation,
    String? debut,
    String? fin,
    String? statut,
    String? categorieCode,
    String? sousCategorieLibelle,
    int? vehiculeId,
    int? chauffeurId,
    String? recherche,
  }) {
    _typeOperation = typeOperation;
    _debut = debut;
    _fin = fin;
    _statut = statut;
    _categorieCode = categorieCode;
    _sousCategorieLibelle = sousCategorieLibelle;
    _vehiculeId = vehiculeId;
    _chauffeurId = chauffeurId;
    _recherche = recherche;
    return _reload();
  }

  /// Recharge avec les filtres déjà en place (pull-to-refresh, retour d'écran).
  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    _page = 0;
    state = state.copyWith(initialLoading: true, clearError: true);
    final res = await _getPage(
      page: 0,
      size: _pageSize,
      typeOperation: _typeOperation,
      debut: _debut,
      fin: _fin,
      statut: _statut,
      categorieCode: _categorieCode,
      sousCategorieLibelle: _sousCategorieLibelle,
      vehiculeId: _vehiculeId,
      chauffeurId: _chauffeurId,
      recherche: _recherche,
    );
    res.fold(
      (f) => state = const OperationsListeState().copyWith(error: f.message),
      (p) => state = OperationsListeState(
        items: p.content,
        hasMore: p.hasMore,
      ),
    );
  }

  /// Charge la page suivante et l'ajoute à la liste (scroll infini).
  Future<void> loadMore() async {
    if (state.loadingMore || state.initialLoading || !state.hasMore) return;
    state = state.copyWith(loadingMore: true, clearError: true);
    final next = _page + 1;
    final res = await _getPage(
      page: next,
      size: _pageSize,
      typeOperation: _typeOperation,
      debut: _debut,
      fin: _fin,
      statut: _statut,
      categorieCode: _categorieCode,
      sousCategorieLibelle: _sousCategorieLibelle,
      vehiculeId: _vehiculeId,
      chauffeurId: _chauffeurId,
      recherche: _recherche,
    );
    res.fold(
      (f) => state = state.copyWith(loadingMore: false, error: f.message),
      (p) {
        _page = next;
        state = state.copyWith(
          items: [...state.items, ...p.content],
          loadingMore: false,
          hasMore: p.hasMore,
        );
      },
    );
  }
}

final _getOpsPageUCProvider = Provider(
  (ref) => GetOperationsFinancieresPageUseCase(
    ref.watch(operationFinanciereRepositoryProvider),
  ),
);

final operationsListeProvider = StateNotifierProvider.autoDispose<
    OperationsListeNotifier, OperationsListeState>((ref) {
  // On garde l'état vivant tant que la page est ouverte, mais on repart propre
  // à chaque nouvelle ouverture de la page Opérations.
  return OperationsListeNotifier(ref.watch(_getOpsPageUCProvider));
});
