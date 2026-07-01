import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/indisponibilite_remote_datasource.dart';
import '../../data/models/indisponibilite_model.dart';
import '../../domain/entities/indisponibilite.dart';
import 'indisponibilite_state.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────

final _secureStorageProvider =
    Provider<SecureStorage>((_) => const SecureStorage());

final _apiClientProvider =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(_secureStorageProvider)));

final indisponibiliteDatasourceProvider =
    Provider<IndisponibiliteRemoteDatasource>(
  (ref) => IndisponibiliteRemoteDatasource(ref.watch(_apiClientProvider)),
);

// ── Notifier ────────────────────────────────────────────────────────────────

class IndisponibiliteNotifier extends StateNotifier<IndisponibiliteState> {
  final IndisponibiliteRemoteDatasource _ds;

  IndisponibiliteNotifier(this._ds) : super(const IndisponibiliteInitial());

  Future<void> load() async {
    state = const IndisponibiliteLoading();
    try {
      final list = await _ds.getIndisponibilites();
      state = IndisponibiliteLoaded(list);
    } catch (e) {
      state = IndisponibiliteError(messageFromError(e));
    }
  }

  Future<String?> create(Indisponibilite i) async {
    try {
      await _ds.create(IndisponibiliteModel(
        chauffeurId: i.chauffeurId,
        chauffeurRemplacantId: i.chauffeurRemplacantId,
        dateDebut: i.dateDebut,
        dateFin: i.dateFin,
        motif: i.motif,
        commentaire: i.commentaire,
      ));
      await load();
      return null;
    } catch (e) {
      return messageFromError(e);
    }
  }

  Future<String?> update(int id, Indisponibilite i) async {
    try {
      await _ds.update(
        id,
        IndisponibiliteModel(
          chauffeurId: i.chauffeurId,
          chauffeurRemplacantId: i.chauffeurRemplacantId,
          dateDebut: i.dateDebut,
          dateFin: i.dateFin,
          motif: i.motif,
          commentaire: i.commentaire,
        ),
      );
      await load();
      return null;
    } catch (e) {
      return messageFromError(e);
    }
  }

  Future<String?> terminer(int id) async {
    try {
      await _ds.terminer(id);
      await load();
      return null;
    } catch (e) {
      return messageFromError(e);
    }
  }

  Future<String?> delete(int id) async {
    try {
      await _ds.delete(id);
      await load();
      return null;
    } catch (e) {
      return messageFromError(e);
    }
  }
}

final indisponibiliteNotifierProvider =
    StateNotifierProvider<IndisponibiliteNotifier, IndisponibiliteState>(
  (ref) =>
      IndisponibiliteNotifier(ref.watch(indisponibiliteDatasourceProvider)),
);

// ── Liste paginée (scroll infini) pour la page Indisponibilités ──────────────

final indisponibilitesListeProvider = StateNotifierProvider.autoDispose<
    PagedListNotifier<Indisponibilite>, PagedListState<Indisponibilite>>(
  (ref) => PagedListNotifier<Indisponibilite>(),
);

/// Indisponibilités actuellement en cours (statut EN_COURS).
/// Utilisé pour signaler un remplacement actif sur l'écran programme.
final indisponibilitesActivesProvider =
    FutureProvider.autoDispose<List<Indisponibilite>>((ref) async {
  final ds = ref.watch(indisponibiliteDatasourceProvider);
  final all = await ds.getIndisponibilites();
  return all.where((i) => i.statut == 'EN_COURS').toList();
});

/// Toutes les indisponibilités (tous statuts), pour calculer l'overlay des
/// remplacements par date dans les calendriers (véhicule / chauffeur).
final toutesIndisponibilitesProvider =
    FutureProvider.autoDispose<List<Indisponibilite>>((ref) async {
  final ds = ref.watch(indisponibiliteDatasourceProvider);
  return ds.getIndisponibilites();
});
