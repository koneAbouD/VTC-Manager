import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:tmk_cache/tmk_cache.dart';

import '../error/failure.dart';
import '../network/api_client.dart';

/// Lecture d'un écran : à la première ouverture, la dernière réponse connue
/// s'affiche le temps que le serveur réponde (voir [afficherEnAttendant]). Un
/// rafraîchissement garde ce que l'écran montre déjà.
///
/// [lecture] est l'appel ordinaire de l'écran (son cas d'usage) : il est
/// rejoué sur le cache seul ([ApiClient.depuisLeCacheSeul]) pour trouver la
/// dernière réponse, sans variante « cache » à écrire pour chaque écran.
///
/// Un échec du serveur remonte comme avant : son message devient l'erreur du
/// provider.
///
/// `FutureProviderRef` est la seule prise sur l'état d'un FutureProvider en
/// Riverpod 2 ; il disparaîtra avec le passage aux Notifier de Riverpod 3.
Future<T> lectureAvecCache<T>(
  // ignore: deprecated_member_use
  FutureProviderRef<T> ref,
  Future<Either<Failure, T>> Function() lecture,
) async {
  final serveur = lecture();
  if (!ref.state.hasValue) {
    var actif = true;
    ref.onDispose(() => actif = false);
    await afficherEnAttendant<T>(
      enAttente: serveur,
      cache: () async =>
          (await ApiClient.depuisLeCacheSeul(lecture)).toNullable(),
      afficher: (donnees) {
        if (actif) ref.state = AsyncData(donnees);
      },
    );
  }
  return (await serveur).fold((f) => throw f.message, (r) => r);
}
