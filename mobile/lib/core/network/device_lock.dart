import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Verrouillage de l'appareil, observé côté natif.
///
/// Le cycle de vie Flutter ne sait pas distinguer « le téléphone vient d'être
/// verrouillé » de « l'utilisateur a basculé vers une autre application » :
/// les deux passent par [AppLifecycleState.paused]. Or les conséquences ne
/// sont pas les mêmes — photographier une quittance ne doit pas redemander le
/// code, verrouiller son téléphone si. D'où ce canal, alimenté par des signaux
/// que seule la plateforme possède.
///
/// C'est le verrouillage qui est suivi, pas l'extinction de l'écran : les deux
/// systèmes laissent un délai réglable entre l'un et l'autre, pendant lequel
/// l'appareil n'est pas verrouillé — l'application n'a donc pas à l'être. Sur
/// chaque plateforme, un signal donne le verrouillage et un second le
/// déverrouillage, ce dernier valant constat rétroactif quand le premier n'a
/// pas été reçu (application suspendue, verrouillage différé) :
///
///  • Android — `ACTION_SCREEN_OFF` (keyguard déjà armé) et `ACTION_USER_PRESENT`
///  • iOS — `protectedDataWillBecomeUnavailable` et `protectedDataDidBecomeAvailable`
///
/// Sur un appareil sans code de verrouillage, aucun ne se déclenche : il n'y a
/// alors rien à verrouiller, et l'application n'a pas à se montrer plus stricte
/// que l'appareil qui l'héberge.
class DeviceLock {
  DeviceLock._();
  static final DeviceLock instance = DeviceLock._();

  static const _channel = EventChannel('vtc/device_lock');

  Stream<void>? _stream;

  /// Émet à chaque verrouillage de l'appareil.
  ///
  /// Flux vide (sans erreur) là où le canal n'existe pas — le web, le bureau,
  /// ou les tests — de sorte que l'appelant n'ait pas à s'en soucier.
  Stream<void> get onDeviceLocked {
    if (kIsWeb) return const Stream.empty();
    return _stream ??= _channel
        .receiveBroadcastStream()
        .map<void>((_) {})
        .handleError((Object _) {});
  }
}
