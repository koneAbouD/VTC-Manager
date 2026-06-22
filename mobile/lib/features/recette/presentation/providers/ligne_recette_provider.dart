import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/ligne_recette_remote_datasource.dart';
import '../../data/repositories_impl/ligne_recette_repository_impl.dart';
import '../../domain/entities/encaissement.dart';
import '../../domain/entities/ligne_recette.dart';
import '../../domain/entities/ligne_recette_filtres.dart';
import '../../domain/repositories/ligne_recette_repository.dart';
import 'ligne_recette_state.dart';

// ── Datasource → Repository ───────────────────────────────────────────────────

final _ligneRecetteDatasourceProvider = Provider<LigneRecetteRemoteDatasource>(
  (ref) => LigneRecetteRemoteDatasource(ref.watch(apiClientProvider)),
);

final ligneRecetteRepositoryProvider = Provider<LigneRecetteRepository>(
  (ref) => LigneRecetteRepositoryImpl(ref.watch(_ligneRecetteDatasourceProvider)),
);

// ── Detail par ID (FutureProvider.family) ────────────────────────────────────

final ligneRecetteDetailProvider =
    FutureProvider.family<LigneRecette, int>((ref, id) async {
  final repo = ref.watch(ligneRecetteRepositoryProvider);
  final result = await repo.getLigneById(id);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (ligne) => ligne,
  );
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class LigneRecetteNotifier extends StateNotifier<LigneRecetteState> {
  final LigneRecetteRepository _repository;

  LigneRecetteNotifier(this._repository) : super(const LigneRecetteInitial());

  Future<void> load([LigneRecetteFiltres? filtres]) async {
    state = const LigneRecetteLoading();
    final result = await _repository.getLignes(
      vehiculeId: filtres?.vehiculeId,
      chauffeurId: filtres?.chauffeurId,
      statut: filtres?.statut,
      dateDebut: filtres?.dateDebut,
      dateFin: filtres?.dateFin,
    );
    result.fold(
      (failure) => state = LigneRecetteError(failure.message),
      (lignes) => state = LigneRecetteLoaded(lignes),
    );
  }

  Future<String?> createEncaissement(int ligneId, Encaissement encaissement) async {
    final result = await _repository.createEncaissement(ligneId, encaissement);
    return result.fold(
      (failure) => failure.message,
      (_) { load(); return null; },
    );
  }

  Future<String?> annuler(int id) async {
    final result = await _repository.annuler(id);
    return result.fold(
      (failure) => failure.message,
      (_) { load(); return null; },
    );
  }

  Future<String?> confirmerVersement(int id) async {
    final result = await _repository.confirmerVersement(id);
    return result.fold(
      (failure) => failure.message,
      (ligne) {
        final current = state;
        if (current is LigneRecetteLoaded) {
          state = LigneRecetteLoaded(
            current.lignes.map((l) => l.id == id ? ligne : l).toList(),
          );
        }
        return null;
      },
    );
  }

  Future<String?> generer({DateTime? date}) async {
    final result = await _repository.generer(date: date);
    return result.fold(
      (failure) => failure.message,
      (_) { load(); return null; },
    );
  }
}

final ligneRecetteNotifierProvider =
    StateNotifierProvider<LigneRecetteNotifier, LigneRecetteState>((ref) {
  return LigneRecetteNotifier(ref.watch(ligneRecetteRepositoryProvider));
});
