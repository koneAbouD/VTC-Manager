import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tmk_cache/tmk_cache.dart';

import 'package:vtc_manager/core/network/api_client.dart';
import 'package:vtc_manager/core/storage/secure_storage.dart';
import 'package:vtc_manager/features/operation_financiere/data/datasources/operation_financiere_remote_datasource.dart';
import 'package:vtc_manager/features/operation_financiere/data/repositories_impl/operation_financiere_repository_impl.dart';
import 'package:vtc_manager/features/operation_financiere/domain/usecases/annuler_operation_financiere_usecase.dart';
import 'package:vtc_manager/features/operation_financiere/domain/usecases/create_operation_financiere_usecase.dart';
import 'package:vtc_manager/features/operation_financiere/domain/usecases/get_operations_financieres_page_usecase.dart';
import 'package:vtc_manager/features/operation_financiere/domain/usecases/get_operations_financieres_usecase.dart';
import 'package:vtc_manager/features/operation_financiere/domain/usecases/update_operation_financiere_usecase.dart';
import 'package:vtc_manager/features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import 'package:vtc_manager/features/operation_financiere/presentation/providers/operation_financiere_state.dart';
import 'package:vtc_manager/features/operation_financiere/presentation/providers/operations_liste_provider.dart';

/// Les opérations, sur l'accueil et sur la page Finances : à l'ouverture, la
/// dernière liste connue s'affiche le temps que le serveur réponde, au lieu
/// d'un indicateur de chargement ; un rafraîchissement, lui, garde la liste
/// affichée.
class _SansJeton extends SecureStorage {
  const _SansJeton();

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;
}

void main() {
  late ReponseCache cache;
  late Completer<http.Response> serveur;
  late ApiClient client;

  setUp(() {
    cache = ReponseCache(
      stockage: StockageMemoire(),
      chiffreur: ChiffreurCache.avecCle(List.filled(32, 5)),
    );
    serveur = Completer();
    client = ApiClient(
      const _SansJeton(),
      MockClient((_) => serveur.future),
      cache,
      EtatHorsLigne(),
    );
  });

  /// Une ouverture de l'application : un notifier neuf, comme au démarrage.
  OperationFinanciereNotifier ouverture() {
    final repo = OperationFinanciereRepositoryImpl(
        OperationFinanciereRemoteDatasource(client));
    return OperationFinanciereNotifier(
      getAll: GetOperationsFinancieresUseCase(repo),
      create: CreateOperationFinanciereUseCase(repo),
      update: UpdateOperationFinanciereUseCase(repo),
      annuler: AnnulerOperationFinanciereUseCase(repo),
    );
  }

  http.Response operations(List<int> ids) => http.Response(
      jsonEncode([
        for (final id in ids)
          {
            'id': id,
            'typeOperation': 'REVENU',
            'montant': 15000,
            'dateOperation': '2026-10-26',
          }
      ]),
      200);

  List<int?> affichees(OperationFinanciereNotifier n) => switch (n.state) {
        OperationFinanciereLoaded(:final operations) =>
          [for (final o in operations) o.id],
        _ => const [],
      };

  test("à l'ouverture suivante, la dernière liste s'affiche aussitôt", () async {
    // Première ouverture : le serveur répond, la liste rejoint le cache.
    serveur.complete(operations([1, 2]));
    await ouverture().loadAll();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Ouverture suivante : le serveur tarde.
    serveur = Completer();
    final accueil = ouverture();
    final chargement = accueil.loadAll();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(accueil.state, isA<OperationFinanciereLoaded>(),
        reason: "pas d'indicateur de chargement : la liste connue est là");
    expect(affichees(accueil), [1, 2]);

    serveur.complete(operations([3, 1, 2]));
    await chargement;
    expect(affichees(accueil), [3, 1, 2]);
  });

  test('toute première ouverture (rien en cache) : chargement, comme avant',
      () async {
    final accueil = ouverture();
    final chargement = accueil.loadAll();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(accueil.state, isA<OperationFinanciereLoading>());

    serveur.complete(operations([1]));
    await chargement;
    expect(affichees(accueil), [1]);
  });

  group('page Finances (liste paginée)', () {
    late List<Completer<http.Response>> reponses;

    setUp(() {
      reponses = [];
      client = ApiClient(
        const _SansJeton(),
        MockClient((_) {
          final r = Completer<http.Response>();
          reponses.add(r);
          return r.future;
        }),
        cache,
        EtatHorsLigne(),
      );
    });

    OperationsListeNotifier liste() => OperationsListeNotifier(
        GetOperationsFinancieresPageUseCase(OperationFinanciereRepositoryImpl(
            OperationFinanciereRemoteDatasource(client))));

    http.Response page(int premier, {bool last = false}) => http.Response(
        jsonEncode({
          'content': [
            for (var id = premier; id < premier + 20; id++)
              {
                'id': id,
                'typeOperation': 'REVENU',
                'montant': 1000,
                'dateOperation': '2026-10-26',
              }
          ],
          'page': 0,
          'size': 20,
          'last': last,
        }),
        200);

    Future<void> repondre(http.Response r) async {
      while (reponses.isEmpty || reponses.last.isCompleted) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      reponses.last.complete(r);
    }

    test('tirer pour rafraîchir garde les pages déjà affichées', () async {
      final ops = liste();
      final chargement = ops.load();
      await repondre(page(0));
      await chargement;
      final suite = ops.loadMore();
      await repondre(page(20));
      await suite;
      expect(ops.state.items, hasLength(40));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final rafraichi = ops.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(ops.state.items, hasLength(40),
          reason: 'pas de retour à la première page du cache');

      await repondre(page(0));
      await rafraichi;
    });

    test("à l'ouverture, la première page connue s'affiche aussitôt", () async {
      final premiere = liste();
      final c = premiere.load();
      await repondre(page(0));
      await c;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ops = liste();
      final chargement = ops.load();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(ops.state.items, hasLength(20));

      await repondre(page(0, last: true));
      await chargement;
    });
  });
}
