import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/indisponibilite_vehicule_remote_datasource.dart';
import '../../data/models/indisponibilite_vehicule_model.dart';
import '../../domain/entities/indisponibilite_vehicule.dart';
import 'indisponibilite_vehicule_state.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────

final _secureStorageProvider =
    Provider<SecureStorage>((_) => const SecureStorage());

final _apiClientProvider =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(_secureStorageProvider)));

final indisponibiliteVehiculeDatasourceProvider =
    Provider<IndisponibiliteVehiculeRemoteDatasource>(
  (ref) =>
      IndisponibiliteVehiculeRemoteDatasource(ref.watch(_apiClientProvider)),
);

// ── Notifier ────────────────────────────────────────────────────────────────

class IndisponibiliteVehiculeNotifier
    extends StateNotifier<IndisponibiliteVehiculeState> {
  final IndisponibiliteVehiculeRemoteDatasource _ds;

  IndisponibiliteVehiculeNotifier(this._ds)
      : super(const IndisponibiliteVehiculeInitial());

  Future<void> load() async {
    state = const IndisponibiliteVehiculeLoading();
    try {
      final list = await _ds.getAll();
      state = IndisponibiliteVehiculeLoaded(list);
    } catch (e) {
      state = IndisponibiliteVehiculeError(messageFromError(e));
    }
  }

  Future<String?> create(IndisponibiliteVehicule i) async {
    try {
      await _ds.create(IndisponibiliteVehiculeModel(
        vehiculeId: i.vehiculeId,
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

  Future<String?> update(int id, IndisponibiliteVehicule i) async {
    try {
      await _ds.update(
        id,
        IndisponibiliteVehiculeModel(
          vehiculeId: i.vehiculeId,
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

final indisponibiliteVehiculeNotifierProvider = StateNotifierProvider<
    IndisponibiliteVehiculeNotifier, IndisponibiliteVehiculeState>(
  (ref) => IndisponibiliteVehiculeNotifier(
      ref.watch(indisponibiliteVehiculeDatasourceProvider)),
);

// ── Liste paginée (scroll infini) ────────────────────────────────────────────

final indisponibilitesVehiculeListeProvider = StateNotifierProvider.autoDispose<
    PagedListNotifier<IndisponibiliteVehicule>,
    PagedListState<IndisponibiliteVehicule>>(
  (ref) => PagedListNotifier<IndisponibiliteVehicule>(),
);
