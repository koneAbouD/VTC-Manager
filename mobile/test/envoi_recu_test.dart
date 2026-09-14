import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:vtc_manager/core/error/failure.dart';
import 'package:vtc_manager/core/utils/recu_paiement.dart';
import 'package:vtc_manager/features/recu/domain/repositories/recu_repository.dart';
import 'package:vtc_manager/features/recu/presentation/envoi_recu.dart';

/// L'envoi du reçu PDF, du serveur jusqu'au canal natif qui l'adresse à
/// WhatsApp : ce qui part, vers qui, et ce que l'écran apprend en retour.
class _Recus implements RecuRepository {
  final Either<Failure, Uint8List> reponse;
  final List<List<int>> demandes = [];

  _Recus(this.reponse);

  @override
  Future<Either<Failure, Uint8List>> getRecuPdf(List<int> operationIds) async {
    demandes.add(operationIds);
    return reponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('vtc/partage');
  final appels = <MethodCall>[];
  String? reponseNative;

  setUp(() {
    appels.clear();
    reponseNative = 'WHATSAPP';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
      appels.add(call);
      return reponseNative;
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(canal, null));

  final recu = RecuPaiement(
    chauffeur: 'Aya Traoré',
    vehicule: '1234 AB 01',
    lignes: const [LigneRecu(libelle: 'Recette du 10/09/2026', montant: 15000)],
    modePaiement: 'Espèces',
    date: DateTime(2026, 9, 11),
    resteDu: 0,
  );
  final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);

  test('le nom du fichier se lit sans accent, au nom du chauffeur et du jour', () {
    expect(nomFichierRecu(recu), 'recu_aya_traore_2026-09-11.pdf');
    expect(nomFichierRecu(RecuPaiement(lignes: const [], date: DateTime(2026, 9, 11))),
        'recu_chauffeur_2026-09-11.pdf');
  });

  test('le PDF part dans la conversation du chauffeur, message joint', () async {
    final recus = _Recus(Right(pdf));

    final issue = await envoyerRecuPdf(
      recus: recus,
      operationIds: const [501, 502],
      recu: recu,
      telephone: '07 12 34 56 78',
    );

    expect(recus.demandes, [
      [501, 502]
    ]);
    expect(issue,
        isA<RecuPartage>().having((i) => i.dansWhatsApp, 'dansWhatsApp', isTrue));
    expect(appels.single.method, 'partagerFichier');
    final arguments = appels.single.arguments as Map;
    expect(arguments['nomFichier'], 'recu_aya_traore_2026-09-11.pdf');
    expect(arguments['telephone'], '2250712345678');
    expect(arguments['mime'], 'application/pdf');
    expect(arguments['octets'], pdf);
    expect(arguments['texte'], contains('joint en PDF'));
    expect(arguments['texte'], contains('Bonjour Aya,'));
  });

  test('sans WhatsApp, la feuille de partage prend le relais', () async {
    reponseNative = 'PARTAGE';

    final issue = await envoyerRecuPdf(
        recus: _Recus(Right(pdf)), operationIds: const [501], recu: recu);

    expect(issue,
        isA<RecuPartage>().having((i) => i.dansWhatsApp, 'dansWhatsApp', isFalse));
  });

  test('PDF refusé par le serveur : rien ne part, le motif est rendu', () async {
    final issue = await envoyerRecuPdf(
      recus: _Recus(Left(
          ConflictFailure("L'écriture ENC-2026-000501 a été annulée"))),
      operationIds: const [501],
      recu: recu,
    );

    expect(issue,
        isA<RecuPdfIndisponible>().having((i) => i.motif, 'motif', contains('a été annulée')));
    expect(appels, isEmpty);
  });

  test('sans écriture, le serveur n\'est même pas interrogé', () async {
    final recus = _Recus(Right(pdf));

    final issue =
        await envoyerRecuPdf(recus: recus, operationIds: const [], recu: recu);

    expect(issue, isA<RecuPdfIndisponible>());
    expect(recus.demandes, isEmpty);
  });
}
