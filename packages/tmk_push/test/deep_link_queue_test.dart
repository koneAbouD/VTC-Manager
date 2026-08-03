import 'package:flutter_test/flutter_test.dart';
import 'package:tmk_push/tmk_push.dart';

void main() {
  late DeepLinkQueue file;

  setUp(() => file = DeepLinkQueue());
  tearDown(() => file.fermer());

  PushMessage message(String type) => PushMessage(type: type);

  test('retient le lien tant que l\'application est sous clé', () async {
    final recus = <PushMessage>[];
    file.flux.listen(recus.add);

    file.deposer(message('PENALITE_APPLIQUEE'));
    await pumpEventQueue();

    expect(recus, isEmpty);
    expect(file.aUnLienEnAttente, isTrue);
  });

  test('rejoue le lien retenu au déverrouillage', () async {
    final recus = <PushMessage>[];
    file.flux.listen(recus.add);

    file.deposer(message('PENALITE_APPLIQUEE'));
    file.marquerPrete();
    await pumpEventQueue();

    expect(recus.map((m) => m.type), ['PENALITE_APPLIQUEE']);
    expect(file.aUnLienEnAttente, isFalse);
  });

  test('émet immédiatement quand l\'application est déjà prête', () async {
    final recus = <PushMessage>[];
    file.flux.listen(recus.add);

    file.marquerPrete();
    file.deposer(message('TEST'));
    await pumpEventQueue();

    expect(recus.map((m) => m.type), ['TEST']);
  });

  test('ne garde que le dernier lien touché', () async {
    final recus = <PushMessage>[];
    file.flux.listen(recus.add);

    file.deposer(message('PENALITE_APPLIQUEE'));
    file.deposer(message('ARRETE_COMPTE_DISPONIBLE'));
    file.marquerPrete();
    await pumpEventQueue();

    expect(recus.map((m) => m.type), ['ARRETE_COMPTE_DISPONIBLE']);
  });

  test('retient de nouveau après un reverrouillage', () async {
    final recus = <PushMessage>[];
    file.flux.listen(recus.add);

    file.marquerPrete();
    file.marquerVerrouillee();
    file.deposer(message('TEST'));
    await pumpEventQueue();

    expect(recus, isEmpty);
    expect(file.aUnLienEnAttente, isTrue);
  });

  test('abandonne le lien de la session qui se ferme', () async {
    final recus = <PushMessage>[];
    file.flux.listen(recus.add);

    file.deposer(message('PENALITE_APPLIQUEE'));
    file.vider();
    file.marquerPrete();
    await pumpEventQueue();

    // Le lien visait le compte précédent : il ne doit pas s'ouvrir pour le
    // suivant, qui n'a rien à voir avec cette pénalité.
    expect(recus, isEmpty);
  });
}
