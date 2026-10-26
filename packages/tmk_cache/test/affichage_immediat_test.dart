import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_cache/tmk_cache.dart';

void main() {
  test('affiche le cache tant que le serveur n\'a pas répondu', () async {
    final serveur = Completer<List<int>>();
    final affiche = <List<int>>[];

    await afficherEnAttendant<List<int>>(
      enAttente: serveur.future,
      cache: () async => [1],
      afficher: affiche.add,
    );

    expect(affiche, [
      [1]
    ]);
    serveur.complete([1, 2]);
  });

  test("n'écrase jamais une réponse déjà arrivée", () async {
    final affiche = <List<int>>[];
    final serveur = Future.value([1, 2]);
    await Future<void>.delayed(Duration.zero);

    await afficherEnAttendant<List<int>>(
      enAttente: serveur,
      cache: () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return [1];
      },
      afficher: affiche.add,
    );

    expect(affiche, isEmpty);
  });

  test('rien en cache, ou cache illisible : on attend le serveur', () async {
    final affiche = <int>[];
    final serveur = Completer<int>();

    await afficherEnAttendant<int>(
      enAttente: serveur.future,
      cache: () async => null,
      afficher: affiche.add,
    );
    await afficherEnAttendant<int>(
      enAttente: serveur.future,
      cache: () => throw const FormatException('ancien format'),
      afficher: affiche.add,
    );

    expect(affiche, isEmpty);
    serveur.complete(1);
  });

  test('un cache bloqué ne retient pas la lecture', () async {
    final affiche = <int>[];

    await afficherEnAttendant<int>(
      enAttente: Future.value(2),
      cache: () => Completer<int?>().future,
      afficher: affiche.add,
    );

    expect(affiche, isEmpty);
  });

  test("une erreur du serveur n'est pas signalée comme non traitée", () async {
    final serveur = Future<int>.error(StateError('500'));

    await afficherEnAttendant<int>(
      enAttente: serveur,
      cache: () async => 1,
      afficher: (_) {},
    );

    await expectLater(serveur, throwsStateError);
  });
}
