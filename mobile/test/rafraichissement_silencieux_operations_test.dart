import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:vtc_manager/core/error/failure.dart';
import 'package:vtc_manager/core/network/page_result.dart';
import 'package:vtc_manager/features/operation_financiere/domain/entities/operation_financiere.dart';
import 'package:vtc_manager/features/operation_financiere/domain/enums/type_operation.dart';
import 'package:vtc_manager/features/operation_financiere/domain/repositories/operation_financiere_repository.dart';
import 'package:vtc_manager/features/operation_financiere/domain/usecases/annuler_operation_financiere_usecase.dart';
import 'package:vtc_manager/features/operation_financiere/domain/usecases/create_operation_financiere_usecase.dart';
import 'package:vtc_manager/features/operation_financiere/domain/usecases/get_operations_financieres_page_usecase.dart';
import 'package:vtc_manager/features/operation_financiere/domain/usecases/get_operations_financieres_usecase.dart';
import 'package:vtc_manager/features/operation_financiere/domain/usecases/update_operation_financiere_usecase.dart';
import 'package:vtc_manager/features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import 'package:vtc_manager/features/operation_financiere/presentation/providers/operation_financiere_state.dart';
import 'package:vtc_manager/features/operation_financiere/presentation/providers/operations_liste_provider.dart';

/// Après un encaissement ou une dépense, les listes d'opérations (accueil et
/// Finances) se rafraîchissent **sans rien montrer** : la liste affichée reste
/// en place pendant l'appel, et une erreur passagère ne l'efface pas.
OperationFinanciere _op(int id) => OperationFinanciere(
      id: id,
      typeOperation: TypeOperation.REVENU,
      categorieCode: 'ENCAISSEMENT_RECETTES',
      categorieLibelle: 'Recette',
      montant: 1000,
      dateOperation: DateTime(2026, 9, 27),
    );

/// Dépôt piloté par le test : chaque appel attend la réponse qu'on lui donne.
class _Repo implements OperationFinanciereRepository {
  Completer<Either<Failure, List<OperationFinanciere>>>? tout;
  Completer<Either<Failure, PageResult<OperationFinanciere>>>? page;
  final List<({int page, int size})> pagesDemandees = [];

  @override
  Future<Either<Failure, List<OperationFinanciere>>> getAll({
    String? typeOperation,
    String? debut,
    String? fin,
    String? statut,
    String? categorieCode,
  }) {
    tout = Completer();
    return tout!.future;
  }

  @override
  Future<Either<Failure, PageResult<OperationFinanciere>>> getPage({
    int page = 0,
    int size = 20,
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
    pagesDemandees.add((page: page, size: size));
    this.page = Completer();
    return this.page!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PageResult<OperationFinanciere> _page(List<OperationFinanciere> ops,
        {bool last = false}) =>
    PageResult(
      content: ops,
      page: 0,
      size: ops.length,
      totalElements: ops.length,
      totalPages: 1,
      last: last,
    );

void main() {
  group('accueil : dernières opérations', () {
    late _Repo repo;
    late OperationFinanciereNotifier notifier;

    setUp(() {
      repo = _Repo();
      notifier = OperationFinanciereNotifier(
        getAll: GetOperationsFinancieresUseCase(repo),
        create: CreateOperationFinanciereUseCase(repo),
        update: UpdateOperationFinanciereUseCase(repo),
        annuler: AnnulerOperationFinanciereUseCase(repo),
      );
    });

    test('le premier chargement montre l\'attente', () async {
      final charge = notifier.loadAll();
      expect(notifier.state, isA<OperationFinanciereLoading>());
      repo.tout!.complete(Right([_op(1)]));
      await charge;
      expect(notifier.state, isA<OperationFinanciereLoaded>());
    });

    test('un rechargement garde la liste affichée jusqu\'à la nouvelle',
        () async {
      final premier = notifier.loadAll();
      repo.tout!.complete(Right([_op(1)]));
      await premier;

      final second = notifier.loadAll();
      final pendant = notifier.state as OperationFinanciereLoaded;
      expect(pendant.operations.map((o) => o.id), [1]);

      repo.tout!.complete(Right([_op(2), _op(1)]));
      await second;
      final apres = notifier.state as OperationFinanciereLoaded;
      expect(apres.operations.map((o) => o.id), [2, 1]);
    });

    test('un échec de rechargement laisse la liste en place', () async {
      final premier = notifier.loadAll();
      repo.tout!.complete(Right([_op(1)]));
      await premier;

      final second = notifier.loadAll();
      repo.tout!.complete(const Left(NetworkFailure('hors ligne')));
      await second;
      expect(notifier.state, isA<OperationFinanciereLoaded>());
    });

    test('seule la réponse la plus récente s\'affiche', () async {
      final premier = notifier.loadAll();
      repo.tout!.complete(Right([_op(1)]));
      await premier;

      final ancien = notifier.loadAll();
      final repAncien = repo.tout!;
      final recent = notifier.loadAll();
      repo.tout!.complete(Right([_op(3)]));
      await recent;
      repAncien.complete(Right([_op(2)]));
      await ancien;

      final etat = notifier.state as OperationFinanciereLoaded;
      expect(etat.operations.map((o) => o.id), [3]);
    });
  });

  group('Finances : liste paginée', () {
    late _Repo repo;
    late OperationsListeNotifier notifier;

    setUp(() {
      repo = _Repo();
      notifier = OperationsListeNotifier(GetOperationsFinancieresPageUseCase(repo));
    });

    Future<void> chargerDeuxPages() async {
      final l = notifier.load();
      repo.page!.complete(Right(_page(List.generate(20, _op))));
      await l;
      final plus = notifier.loadMore();
      repo.page!.complete(Right(_page(List.generate(20, (i) => _op(20 + i)))));
      await plus;
    }

    test('rafraîchir garde la liste, sans roue, et recharge autant d\'opérations',
        () async {
      await chargerDeuxPages();
      expect(notifier.state.items, hasLength(40));

      final r = notifier.rafraichir();
      expect(notifier.state.initialLoading, isFalse);
      expect(notifier.state.items, hasLength(40));
      expect(repo.pagesDemandees.last, (page: 0, size: 40));

      repo.page!.complete(Right(_page(List.generate(40, (i) => _op(100 + i)))));
      await r;
      expect(notifier.state.items.first.id, 100);
      expect(notifier.state.items, hasLength(40));

      // Le défilement reprend après ce qui est déjà chargé : page 2 (taille 20).
      final plus = notifier.loadMore();
      expect(repo.pagesDemandees.last, (page: 2, size: 20));
      repo.page!.complete(Right(_page([], last: true)));
      await plus;
    });

    test('un échec de rafraîchissement laisse la liste telle quelle', () async {
      await chargerDeuxPages();
      final r = notifier.rafraichir();
      repo.page!.complete(const Left(NetworkFailure('hors ligne')));
      await r;
      expect(notifier.state.items, hasLength(40));
      expect(notifier.state.error, isNull);
    });
  });
}
