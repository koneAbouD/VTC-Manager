import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:vtc_manager/core/error/failure.dart';
import 'package:vtc_manager/core/utils/recu_paiement.dart';
import 'package:vtc_manager/features/recu/domain/repositories/recu_repository.dart';
import 'package:vtc_manager/features/recu/presentation/envoi_recu.dart';

/// L'envoi du reçu PDF : avec un numéro, droit à la conversation du chauffeur,
/// PDF enregistré à joindre ; sans numéro, PDF joint et contact à choisir.
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
  final appelsNatifs = <MethodCall>[];
  String? reponsePartage;

  final enregistres = <(String, String)>[];
  final conversations = <(String?, String)>[];
  var whatsappOuvrable = true;

  Future<String?> enregistrer(Uint8List octets, String nom, String mime) async {
    enregistres.add((nom, mime));
    return 'Téléchargements/$nom';
  }

  Future<bool> ouvrir({String? telephone, required String message}) async {
    conversations.add((telephone, message));
    return whatsappOuvrable;
  }

  setUp(() {
    appelsNatifs.clear();
    enregistres.clear();
    conversations.clear();
    whatsappOuvrable = true;
    reponsePartage = 'WHATSAPP';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
      appelsNatifs.add(call);
      return call.method == 'partagerFichier' ? reponsePartage : null;
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

  Future<IssueEnvoiPdf> envoyer({
    Either<Failure, Uint8List>? reponse,
    List<int> operationIds = const [501, 502],
    String? telephone,
  }) =>
      envoyerRecuPdf(
        recus: _Recus(reponse ?? Right(pdf)),
        operationIds: operationIds,
        recu: recu,
        telephone: telephone,
        ouvrirConversation: ouvrir,
        enregistrerFichier: enregistrer,
      );

  group('nom du fichier', () {
    RecuPaiement pour({String? vehicule, String? chauffeur}) => RecuPaiement(
        vehicule: vehicule,
        chauffeur: chauffeur,
        lignes: const [],
        date: DateTime(2026, 9, 11));

    test('immatriculation du véhicule, puis date au format français', () {
      expect(nomFichierRecu(recu), 'recu_1234-AB-01_11-09-2026.pdf');
    });

    test('la plaque garde ses caractères, reliés par des tirets', () {
      expect(nomFichierRecu(pour(vehicule: 'AA-123-BB')), 'recu_AA-123-BB_11-09-2026.pdf');
      expect(nomFichierRecu(pour(vehicule: ' 5678  cd 01 ')), 'recu_5678-CD-01_11-09-2026.pdf');
    });

    // Un lot sur plusieurs véhicules n'a pas de plaque unique à nommer.
    test('sans véhicule unique, le chauffeur tient lieu de plaque', () {
      expect(nomFichierRecu(pour(chauffeur: 'Aya Traoré')), 'recu_aya_traore_11-09-2026.pdf');
    });

    test('sans véhicule ni chauffeur, la date seule', () {
      expect(nomFichierRecu(pour()), 'recu_11-09-2026.pdf');
    });
  });

  test('avec un numéro : PDF enregistré, conversation du chauffeur ouverte, '
      'message prêt', () async {
    final issue = await envoyer(telephone: '07 12 34 56 78');

    expect(enregistres, [('recu_1234-AB-01_11-09-2026.pdf', 'application/pdf')]);
    expect(conversations.single.$1, '07 12 34 56 78');
    expect(conversations.single.$2, contains('Bonjour Aya,'));
    expect(conversations.single.$2, contains('envoyé en PDF'));
    // Le toast dit où trouver le fichier, avant que WhatsApp ne prenne la main.
    final annonce = appelsNatifs.single;
    expect(annonce.method, 'annoncer');
    expect((annonce.arguments as Map)['texte'], contains('Téléchargements'));
    // Pas de partage de fichier : il ouvrirait « Envoyer à… » au lieu du chauffeur.
    expect(appelsNatifs.where((c) => c.method == 'partagerFichier'), isEmpty);
    expect(
        issue,
        isA<PdfEnregistre>()
            .having((i) => i.emplacement, 'emplacement',
                'Téléchargements/recu_1234-AB-01_11-09-2026.pdf')
            .having((i) => i.conversationOuverte, 'conversationOuverte', isTrue));
  });

  test('avec un numéro, WhatsApp impossible à ouvrir : le PDF reste enregistré '
      'et l\'écran le saura', () async {
    whatsappOuvrable = false;

    final issue = await envoyer(telephone: '07 12 34 56 78');

    expect(enregistres, hasLength(1));
    expect(issue,
        isA<PdfEnregistre>().having((i) => i.conversationOuverte, 'ouverte', isFalse));
  });

  test('sans numéro : le PDF part joint, WhatsApp demande le contact', () async {
    final issue = await envoyer(telephone: null);

    final partage = appelsNatifs.single;
    expect(partage.method, 'partagerFichier');
    final arguments = partage.arguments as Map;
    expect(arguments['nomFichier'], 'recu_1234-AB-01_11-09-2026.pdf');
    expect(arguments['octets'], pdf);
    expect(arguments['texte'], contains('envoyé en PDF'));
    expect(arguments.containsKey('telephone'), isFalse);
    expect(enregistres, isEmpty);
    expect(conversations, isEmpty);
    expect(issue,
        isA<PdfPartage>().having((i) => i.dansWhatsApp, 'dansWhatsApp', isTrue));
  });

  test('sans numéro ni WhatsApp : la feuille de partage prend le relais', () async {
    reponsePartage = 'PARTAGE';

    final issue = await envoyer(telephone: '');

    expect(issue,
        isA<PdfPartage>().having((i) => i.dansWhatsApp, 'dansWhatsApp', isFalse));
  });

  test('PDF refusé par le serveur : rien n\'est enregistré ni ouvert', () async {
    final issue = await envoyer(
      reponse: Left(ConflictFailure("L'écriture ENC-2026-000501 a été annulée")),
      telephone: '07 12 34 56 78',
    );

    expect(issue,
        isA<PdfIndisponible>().having((i) => i.motif, 'motif', contains('a été annulée')));
    expect(enregistres, isEmpty);
    expect(conversations, isEmpty);
    expect(appelsNatifs, isEmpty);
  });

  test('sans écriture, le serveur n\'est même pas interrogé', () async {
    final recus = _Recus(Right(pdf));

    final issue = await envoyerRecuPdf(
        recus: recus, operationIds: const [], recu: recu, telephone: '0712345678');

    expect(issue, isA<PdfIndisponible>());
    expect(recus.demandes, isEmpty);
  });
}
