import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/ligne_cotisation_remote_datasource.dart';
import '../../data/repositories_impl/ligne_cotisation_repository_impl.dart';
import '../../domain/entities/encaissement_cotisation.dart';
import '../../domain/entities/ligne_cotisation.dart';
import '../../domain/entities/ligne_cotisation_filtres.dart';
import '../../domain/entities/totaux_cotisation.dart';
import '../../domain/repositories/ligne_cotisation_repository.dart';
import 'ligne_cotisation_state.dart';

// ── Datasource → Repository ───────────────────────────────────────────────────

final _ligneCotisationDatasourceProvider = Provider<LigneCotisationRemoteDatasource>(
  (ref) => LigneCotisationRemoteDatasource(ref.watch(apiClientProvider)),
);

final ligneCotisationRepositoryProvider = Provider<LigneCotisationRepository>(
  (ref) => LigneCotisationRepositoryImpl(ref.watch(_ligneCotisationDatasourceProvider)),
);

// ── Detail par ID ─────────────────────────────────────────────────────────────

/// `autoDispose` : la fiche porte le drapeau `restaurable`, instantané des
/// arrêtés comptables pris au chargement. Conservée pour la vie de l'app,
/// elle proposerait encore « Restaurer » après une clôture de caisse — un
/// bouton que le serveur refuserait. On la relit donc à chaque ouverture.
final ligneCotisationDetailProvider =
    FutureProvider.autoDispose.family<LigneCotisation, int>((ref, id) async {
  final result = await ref.watch(ligneCotisationRepositoryProvider).getLigneById(id);
  return result.fold((f) => throw Exception(f.message), (l) => l);
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class LigneCotisationNotifier extends StateNotifier<LigneCotisationState> {
  final LigneCotisationRepository _repository;
  LigneCotisationNotifier(this._repository) : super(const LigneCotisationInitial());

  Future<void> load([LigneCotisationFiltres? filtres]) async {
    state = const LigneCotisationLoading();
    final result = await _repository.getLignes(filtres ?? const LigneCotisationFiltres());
    result.fold(
      (f) => state = LigneCotisationError(f.message),
      (l) => state = LigneCotisationLoaded(l),
    );
  }

  Future<String?> createEncaissement(int ligneId, EncaissementCotisation enc) async {
    final result = await _repository.createEncaissement(ligneId, enc);
    return result.fold((f) => f.message, (_) { load(); return null; });
  }

  Future<String?> annuler(int id, String motif) async {
    final result = await _repository.annuler(id, motif);
    return result.fold((f) => f.message, (_) { load(); return null; });
  }

  Future<String?> restaurer(int id) async {
    final result = await _repository.restaurer(id);
    return result.fold((f) => f.message, (_) { load(); return null; });
  }

  Future<String?> generer({DateTime? date}) async {
    final result = await _repository.generer(date: date);
    return result.fold((f) => f.message, (_) { load(); return null; });
  }
}

final ligneCotisationNotifierProvider =
    StateNotifierProvider<LigneCotisationNotifier, LigneCotisationState>((ref) {
  return LigneCotisationNotifier(ref.watch(ligneCotisationRepositoryProvider));
});

// ── Cumuls de la sélection ───────────────────────────────────────────────────

/// Montants des pastilles de statut. Séparé de la liste parce qu'il ne suit pas
/// la pagination : ils portent sur toute la sélection, pas sur les pages
/// chargées. Une erreur de chargement retombe sur des montants vides plutôt que
/// de masquer la liste — la page reste utilisable sans ses compteurs.
class TotauxCotisationNotifier extends StateNotifier<TotauxCotisation> {
  final LigneCotisationRepository _repository;
  TotauxCotisationNotifier(this._repository) : super(TotauxCotisation.vide);

  Future<void> charger(LigneCotisationFiltres filtres) async {
    final result = await _repository.getTotaux(filtres);
    if (!mounted) return;
    state = result.fold((_) => TotauxCotisation.vide, (t) => t);
  }
}

final totauxCotisationProvider = StateNotifierProvider.autoDispose<
    TotauxCotisationNotifier, TotauxCotisation>(
  (ref) => TotauxCotisationNotifier(ref.watch(ligneCotisationRepositoryProvider)),
);

// ── Liste paginée (scroll infini) pour la page Cotisations ───────────────────

final lignesCotisationListeProvider = StateNotifierProvider.autoDispose<
    PagedListNotifier<LigneCotisation>, PagedListState<LigneCotisation>>(
  (ref) => PagedListNotifier<LigneCotisation>(),
);
