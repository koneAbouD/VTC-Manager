import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:vtc_manager/core/error/failure.dart';
import 'package:vtc_manager/features/vehicule/domain/entities/vehicule.dart';
import 'package:vtc_manager/features/vehicule/domain/repositories/vehicule_repository.dart';
import 'package:vtc_manager/features/vehicule/domain/usecases/create_vehicule_usecase.dart';
import 'package:vtc_manager/features/vehicule/domain/usecases/delete_vehicule_usecase.dart';
import 'package:vtc_manager/features/vehicule/domain/usecases/get_vehicules_usecase.dart';
import 'package:vtc_manager/features/vehicule/domain/usecases/update_vehicule_usecase.dart';
import 'package:vtc_manager/features/vehicule/presentation/providers/vehicule_provider.dart';
import 'package:vtc_manager/features/vehicule/presentation/providers/vehicule_state.dart';

/// Sur réseau mobile, la liste de la flotte met plusieurs secondes à
/// arriver : en attendant, l'écran montre la dernière liste connue.
const _a = Vehicule(id: 1, immatriculation: 'AA-111', marque: 'Toyota', modele: 'Yaris');
const _b = Vehicule(id: 2, immatriculation: 'BB-222', marque: 'Kia', modele: 'Rio');

class _Repo implements VehiculeRepository {
  List<Vehicule>? enCache;
  Completer<Either<Failure, List<Vehicule>>> serveur = Completer();

  @override
  Future<Either<Failure, List<Vehicule>>> getVehicules() => serveur.future;

  @override
  Future<List<Vehicule>?> getVehiculesEnCache() async => enCache;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Repo repo;
  late VehiculeNotifier notifier;
  late List<VehiculeState> etats;

  setUp(() {
    repo = _Repo();
    notifier = VehiculeNotifier(
      getVehicules: GetVehiculesUseCase(repo),
      createVehicule: CreateVehiculeUseCase(repo),
      updateVehicule: UpdateVehiculeUseCase(repo),
      deleteVehicule: DeleteVehiculeUseCase(repo),
    );
    etats = [];
    notifier.addListener(etats.add, fireImmediately: false);
  });

  List<List<int>> listes() => [
        for (final e in etats)
          if (e is VehiculeLoaded) [for (final v in e.vehicules) v.id!],
      ];

  test('premier chargement : la liste en cache, puis celle du serveur',
      () async {
    repo.enCache = [_a];
    final chargement = notifier.loadVehicules();
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state, isA<VehiculeLoaded>());
    expect(listes(), [
      [1]
    ]);

    repo.serveur.complete(const Right([_a, _b]));
    await chargement;
    expect(listes(), [
      [1],
      [1, 2]
    ]);
  });

  test('rien en cache : indicateur de chargement, comme avant', () async {
    final chargement = notifier.loadVehicules();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, isA<VehiculeLoading>());

    repo.serveur.complete(const Right([_a]));
    await chargement;
    expect(listes(), [
      [1]
    ]);
  });

  test('rechargement : la liste affichée reste jusqu\'à la nouvelle', () async {
    repo.serveur.complete(const Right([_a]));
    await notifier.loadVehicules();
    etats.clear();

    repo
      ..enCache = [_b]
      ..serveur = Completer();
    final chargement = notifier.loadVehicules();
    await Future<void>.delayed(Duration.zero);
    expect(etats, isEmpty, reason: 'ni indicateur, ni ancienne liste du cache');

    repo.serveur.complete(const Right([_a, _b]));
    await chargement;
    expect(listes(), [
      [1, 2]
    ]);
  });
}
