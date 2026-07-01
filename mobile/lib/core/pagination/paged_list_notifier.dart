import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../error/failure.dart';
import '../network/page_result.dart';

/// Récupère une page donnée. Le fetcher capture les filtres courants de l'écran,
/// il est fourni par la page à chaque (re)chargement.
typedef PageFetcher<T> = Future<Either<Failure, PageResult<T>>> Function(
    int page, int size);

/// État générique d'une liste paginée à scroll infini.
class PagedListState<T> {
  final List<T> items;
  final bool initialLoading; // premier chargement / rechargement filtre
  final bool loadingMore; // chargement de la page suivante
  final bool hasMore; // reste-t-il des pages à charger ?
  final String? error;

  const PagedListState({
    this.items = const [],
    this.initialLoading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
  });

  PagedListState<T> copyWith({
    List<T>? items,
    bool? initialLoading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return PagedListState<T>(
      items: items ?? this.items,
      initialLoading: initialLoading ?? this.initialLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier générique pour listes paginées (scroll infini).
///
/// La page appelle [load] avec un fetcher capturant ses filtres, puis [loadMore]
/// à l'approche du bas de liste et [refresh] au pull-to-refresh / retour d'écran.
class PagedListNotifier<T> extends StateNotifier<PagedListState<T>> {
  PagedListNotifier() : super(PagedListState<T>());

  static const int pageSize = 20;

  int _page = 0;
  PageFetcher<T>? _fetcher;

  /// (Re)charge depuis la page 0 avec un nouveau fetcher (filtres à jour).
  Future<void> load(PageFetcher<T> fetcher) {
    _fetcher = fetcher;
    return _reload();
  }

  /// Recharge avec le dernier fetcher connu (mêmes filtres).
  Future<void> refresh() => _fetcher == null ? Future.value() : _reload();

  Future<void> _reload() async {
    final fetch = _fetcher;
    if (fetch == null) return;
    _page = 0;
    state = state.copyWith(initialLoading: true, clearError: true);
    final res = await fetch(0, pageSize);
    res.fold(
      (f) => state = PagedListState<T>(error: f.message),
      (p) => state = PagedListState<T>(items: p.content, hasMore: p.hasMore),
    );
  }

  /// Charge la page suivante et l'ajoute à la liste.
  Future<void> loadMore() async {
    final fetch = _fetcher;
    if (fetch == null ||
        state.loadingMore ||
        state.initialLoading ||
        !state.hasMore) {
      return;
    }
    state = state.copyWith(loadingMore: true, clearError: true);
    final next = _page + 1;
    final res = await fetch(next, pageSize);
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

/// Loader affiché en bas de liste pendant le chargement de la page suivante.
class PagedListLoadMoreTile extends StatelessWidget {
  const PagedListLoadMoreTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
