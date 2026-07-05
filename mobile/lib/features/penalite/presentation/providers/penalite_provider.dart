import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/penalite_remote_datasource.dart';
import '../../data/repositories_impl/penalite_repository_impl.dart';
import '../../domain/entities/ligne_penalite.dart';
import '../../domain/entities/ligne_penalite_filtres.dart';
import '../../domain/repositories/penalite_repository.dart';
import 'ligne_penalite_state.dart';

// ── Datasource → Repository ───────────────────────────────────────────────────

final _penaliteDatasourceProvider = Provider<PenaliteRemoteDatasource>(
  (ref) => PenaliteRemoteDatasource(ref.watch(apiClientProvider)),
);

final penaliteRepositoryProvider = Provider<PenaliteRepository>(
  (ref) => PenaliteRepositoryImpl(ref.watch(_penaliteDatasourceProvider)),
);

// ── Détail par ID (FutureProvider.family) ────────────────────────────────────

final lignePenaliteDetailProvider =
    FutureProvider.family<LignePenalite, int>((ref, id) async {
  final result = await ref.watch(penaliteRepositoryProvider).getLigneById(id);
  return result.fold((f) => throw Exception(f.message), (l) => l);
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class LignePenaliteNotifier extends StateNotifier<LignePenaliteState> {
  final PenaliteRepository _repository;

  LignePenaliteNotifier(this._repository) : super(const LignePenaliteInitial());

  Future<void> load([LignePenaliteFiltres? filtres]) async {
    state = const LignePenaliteLoading();
    final result =
        await _repository.getLignes(filtres ?? const LignePenaliteFiltres());
    result.fold(
      (f) => state = LignePenaliteError(f.message),
      (l) => state = LignePenaliteLoaded(l),
    );
  }

  Future<String?> createEncaissement(
      int ligneId, Map<String, dynamic> data) async {
    final result = await _repository.createEncaissement(ligneId, data);
    return result.fold((f) => f.message, (_) { load(); return null; });
  }

  Future<String?> executer(int id) async {
    final result = await _repository.executer(id);
    return result.fold((f) => f.message, (_) { load(); return null; });
  }

  Future<String?> notifier(int id) async {
    final result = await _repository.notifier(id);
    return result.fold((f) => f.message, (_) { load(); return null; });
  }

  Future<String?> demarrer(int id) async {
    final result = await _repository.demarrer(id);
    return result.fold((f) => f.message, (_) { load(); return null; });
  }

  Future<String?> lever(int id) async {
    final result = await _repository.lever(id);
    return result.fold((f) => f.message, (_) { load(); return null; });
  }

  Future<String?> annuler(int id, String motif) async {
    final result = await _repository.annuler(id, motif);
    return result.fold((f) => f.message, (_) { load(); return null; });
  }

  Future<String?> generer({DateTime? date}) async {
    final result = await _repository.generer(date: date);
    return result.fold((f) => f.message, (_) { load(); return null; });
  }

  // Encaissement depuis la page détail (recharge le détail via FutureProvider)
  Future<String?> createEncaissementDetail(
      int ligneId, Map<String, dynamic> data) async {
    final result = await _repository.createEncaissement(ligneId, data);
    return result.fold((f) => f.message, (_) => null);
  }

  Future<String?> executerDetail(int id) async =>
      (await _repository.executer(id)).fold((f) => f.message, (_) => null);

  Future<String?> notifierDetail(int id) async =>
      (await _repository.notifier(id)).fold((f) => f.message, (_) => null);

  Future<String?> demarrerDetail(int id) async =>
      (await _repository.demarrer(id)).fold((f) => f.message, (_) => null);

  Future<String?> leverDetail(int id) async =>
      (await _repository.lever(id)).fold((f) => f.message, (_) => null);

  Future<String?> annulerDetail(int id, String motif) async =>
      (await _repository.annuler(id, motif)).fold((f) => f.message, (_) => null);
}

final lignePenaliteNotifierProvider =
    StateNotifierProvider<LignePenaliteNotifier, LignePenaliteState>((ref) {
  return LignePenaliteNotifier(ref.watch(penaliteRepositoryProvider));
});

// ── Liste paginée (scroll infini) pour la page Pénalités ─────────────────────

final lignesPenaliteListeProvider = StateNotifierProvider.autoDispose<
    PagedListNotifier<LignePenalite>, PagedListState<LignePenalite>>(
  (ref) => PagedListNotifier<LignePenalite>(),
);
