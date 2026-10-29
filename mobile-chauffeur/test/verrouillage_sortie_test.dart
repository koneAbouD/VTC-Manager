import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_chauffeur/core/network/session_manager.dart';

/// Quitter l'application la verrouille aussitôt ; seules les sorties qu'elle
/// lance elle-même (appareil photo, sélecteur, partage, WhatsApp) attendent
/// le retour sans redemander le code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messager =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<LockReason> verrous;
  late StreamSubscription<LockReason> abonnement;
  late DateTime maintenant;
  late SessionManager session;

  setUp(() {
    session = SessionManager.instance;
    // Stockage sécurisé et verrouillage de l'appareil : canaux muets.
    messager.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null);
    messager.setMockStreamHandler(const EventChannel('vtc/device_lock'),
        MockStreamHandler.inline(onListen: (_, _) {}));
    maintenant = DateTime(2026, 10, 26, 14);
    session.horloge = () => maintenant;
    verrous = [];
    abonnement = session.onLockRequested.listen(verrous.add);
    session.start();
  });

  tearDown(() async {
    session.stop();
    await abonnement.cancel();
  });

  void cycle(AppLifecycleState etat) => session.didChangeAppLifecycleState(etat);

  Future<void> laisserPasser() => Future<void>.delayed(Duration.zero);

  test('quitter l\'application la verrouille aussitôt', () async {
    cycle(AppLifecycleState.inactive);
    cycle(AppLifecycleState.hidden);
    await laisserPasser();

    expect(verrous, [LockReason.arrierePlan],
        reason: 'verrouillée avant même le retour');

    cycle(AppLifecycleState.paused);
    await laisserPasser();
    expect(verrous, hasLength(1), reason: 'une seule demande');
  });

  test('volet de notifications ou invite système : rien à verrouiller',
      () async {
    cycle(AppLifecycleState.inactive);
    cycle(AppLifecycleState.resumed);
    await laisserPasser();

    expect(verrous, isEmpty);
  });

  test('photo ou fichier : le retour ne redemande pas le code', () async {
    final photo = Completer<String>();
    final prise = session.sortieAttendue(() => photo.future);

    cycle(AppLifecycleState.hidden);
    cycle(AppLifecycleState.paused);
    maintenant = maintenant.add(const Duration(minutes: 2));
    photo.complete('quittance.jpg');
    await prise;
    cycle(AppLifecycleState.resumed);
    await laisserPasser();

    expect(verrous, isEmpty);
  });

  test('sortie voulue mais trop longue : le code est redemandé', () async {
    final photo = Completer<String>();
    final prise = session.sortieAttendue(() => photo.future);

    cycle(AppLifecycleState.paused);
    maintenant = maintenant.add(const Duration(minutes: 11));
    photo.complete('quittance.jpg');
    await prise;
    cycle(AppLifecycleState.resumed);
    await laisserPasser();

    expect(verrous, [LockReason.arrierePlan]);
  });

  test('lien ouvert ailleurs : la sortie juste après l\'appel reste voulue',
      () async {
    await session.sortieAttendue(() async => true); // launchUrl rend la main
    maintenant = maintenant.add(const Duration(seconds: 1));
    cycle(AppLifecycleState.paused);
    await laisserPasser();

    expect(verrous, isEmpty);
  });

  test('passé ce délai, une sortie redevient ordinaire', () async {
    await session.sortieAttendue(() async => true);
    maintenant = maintenant.add(const Duration(seconds: 5));
    cycle(AppLifecycleState.paused);
    await laisserPasser();

    expect(verrous, [LockReason.arrierePlan]);
  });

  test('WhatsApp lent à s\'afficher : la sortie reste voulue', () async {
    await session.sortieAttendue(() async => 'WHATSAPP'); // rend la main aussitôt
    cycle(AppLifecycleState.inactive);
    // Android ne signale le départ qu'une fois WhatsApp prêt.
    maintenant = maintenant.add(const Duration(seconds: 8));
    cycle(AppLifecycleState.hidden);
    cycle(AppLifecycleState.paused);
    maintenant = maintenant.add(const Duration(minutes: 3));
    cycle(AppLifecycleState.resumed);
    await laisserPasser();

    expect(verrous, isEmpty);
  });

  test('feuille de partage : le choix du destinataire peut prendre son temps',
      () async {
    await session.sortieAttendue(() async => 'PARTAGE');
    cycle(AppLifecycleState.inactive); // la feuille se pose par-dessus
    maintenant = maintenant.add(const Duration(seconds: 30));
    cycle(AppLifecycleState.paused); // destinataire choisi
    await laisserPasser();

    expect(verrous, isEmpty);
  });

  test('feuille de partage refermée : la sortie suivante verrouille',
      () async {
    await session.sortieAttendue(() async => 'PARTAGE');
    cycle(AppLifecycleState.inactive);
    maintenant = maintenant.add(const Duration(seconds: 10));
    cycle(AppLifecycleState.resumed); // retour sans rien choisir
    maintenant = maintenant.add(const Duration(seconds: 10));
    cycle(AppLifecycleState.inactive);
    cycle(AppLifecycleState.paused);
    await laisserPasser();

    expect(verrous, [LockReason.arrierePlan]);
  });

  test('volet de notifications hors partage, puis départ : verrouillage',
      () async {
    await session.sortieAttendue(() async => true);
    maintenant = maintenant.add(const Duration(seconds: 5));
    cycle(AppLifecycleState.inactive);
    cycle(AppLifecycleState.paused);
    await laisserPasser();

    expect(verrous, [LockReason.arrierePlan]);
  });

  test('verrouillée pendant une sortie voulue : la sortie suivante verrouille',
      () async {
    final photo = Completer<String>();
    final prise = session.sortieAttendue(() => photo.future);
    cycle(AppLifecycleState.paused);
    // Pendant l'absence, l'appareil se verrouille : la session est fermée.
    session.stop();
    photo.complete('quittance.jpg');
    await prise;

    // Déverrouillée, puis quittée normalement.
    session.start();
    maintenant = maintenant.add(const Duration(seconds: 10));
    cycle(AppLifecycleState.paused);
    await laisserPasser();

    expect(verrous, [LockReason.arrierePlan]);
  });
}
