import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/core/error/exception.dart';
import 'package:vtc_manager/core/utils/envoi_pdf_whatsapp.dart';
import 'package:vtc_manager/core/utils/recu_paiement.dart' show montantRecu;
import 'package:vtc_manager/features/tresorerie/domain/entities/compte_courant.dart';
import 'package:vtc_manager/features/tresorerie/presentation/envoi_decompte_arrete.dart';

/// Le décompte d'un arrêté par véhicule, envoyé à chaque chauffeur : le même
/// PDF pour tous, un message qui parle à chacun de sa part.
///
/// Les fonds s'y mutualisent : le dépôt d'Aya solde la dette de Koffi, qui n'a
/// rien déposé. Koffi n'a donc pas de règlement — il ne se lit que dans les
/// lignes — et doit pourtant recevoir le décompte.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('vtc/partage');
  final appelsNatifs = <MethodCall>[];

  setUp(() {
    appelsNatifs.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
      appelsNatifs.add(call);
      return call.method == 'partagerFichier' ? 'WHATSAPP' : null;
    });
  });

  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(canal, null));

  // Aya dépose 100 000 : 30 000 éteignent sa recette, 50 000 celle de Koffi,
  // et les 20 000 restants lui sont versés en espèces.
  ArreteCompte arreteVehicule() => ArreteCompte(
        id: 12,
        perimetre: 'VEHICULE',
        perimetreId: 4,
        perimetreLibelle: '1234 AB 01',
        periodeDebut: DateTime(2026, 8, 1),
        periodeFin: DateTime(2026, 8, 31),
        dateArrete: DateTime(2026, 9, 1),
        reference: 'ARR-2026-000012',
        statut: 'VALIDE',
        totalRestitue: 20000,
        lignes: const [
          LigneArrete(
              document: 'COTISATION',
              documentId: 1,
              chauffeurId: 3,
              vehiculeId: 4,
              montant: 100000,
              sens: 'CREDIT'),
          LigneArrete(
              document: 'RECETTE',
              documentId: 7,
              chauffeurId: 3,
              vehiculeId: 4,
              montant: 30000,
              sens: 'DEBIT'),
          LigneArrete(
              document: 'RECETTE',
              documentId: 8,
              chauffeurId: 9,
              vehiculeId: 4,
              montant: 50000,
              sens: 'DEBIT'),
        ],
        reglements: const [
          ReglementArrete(
            chauffeurId: 3,
            chauffeurNom: 'Aya Traoré',
            totalCotisations: 100000,
            totalCreancesCompensees: 80000,
            montantNet: 20000,
            reliquatReporte: 0,
            modePaiement: 'ESPECES',
          ),
        ],
      );

  const contacts = [
    ChauffeurArrete(id: 9, nom: 'Koffi Yao', telephone: '0102030405'),
    ChauffeurArrete(id: 3, nom: 'Aya Traoré', telephone: '07 12 34 56 78'),
  ];
  final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);

  group('destinataires', () {
    test('les bénéficiaires d\'abord, puis le chauffeur dont un collègue a '
        'soldé la dette', () {
      final destinataires = destinatairesDecompte(arreteVehicule(), contacts);

      expect(destinataires.map((d) => d.chauffeurId), [3, 9]);
      expect(destinataires.map((d) => d.nom), ['Aya Traoré', 'Koffi Yao']);
      expect(destinataires.map((d) => d.telephone),
          ['07 12 34 56 78', '0102030405']);
    });

    test('sans contact servi, le nom du règlement reste et le numéro manque',
        () {
      final destinataires = destinatairesDecompte(arreteVehicule(), const []);

      expect(destinataires.map((d) => d.nom), ['Aya Traoré', 'Chauffeur #9']);
      expect(destinataires.map((d) => d.telephone), [null, null]);
    });

    test('le contact se lit tel que le serveur le sert', () {
      final contact = ChauffeurArrete.fromJson(
          {'id': 9, 'nom': 'Koffi Yao', 'telephone': null});

      expect(contact.id, 9);
      expect(contact.nom, 'Koffi Yao');
      expect(contact.telephone, isNull);
    });
  });

  group('message', () {
    test('le contributeur voit ce qui a été retenu pour lui et pour autrui', () {
      final aya = destinatairesDecompte(arreteVehicule(), contacts).first;

      final message = aya.messageAvecPdf;

      expect(message, contains('Bonjour Aya,'));
      expect(message,
          contains('du 01/09/2026, période du 01/08/2026 au 31/08/2026'));
      expect(message, contains('• Vos cotisations : ${montantRecu(100000)}'));
      expect(message,
          contains('• Retenu pour vos créances : ${montantRecu(30000)}'));
      expect(
          message,
          contains("• Retenu pour les créances d'autres chauffeurs du véhicule : "
              '${montantRecu(50000)}'));
      expect(message,
          contains('Net restitué : *${montantRecu(20000)}* en espèces'));
      expect(message, contains('Véhicule 1234 AB 01 · Réf. ARR-2026-000012'));
      expect(message, contains('envoyé en PDF'));
      expect(message, isNot(contains('Reste à payer')));
      expect(aya.resume, startsWith('Net restitué'));
    });

    test('celui dont un collègue a soldé la dette l\'apprend, sans versement '
        'annoncé', () {
      final koffi = destinatairesDecompte(arreteVehicule(), contacts).last;

      expect(koffi.message, contains('Bonjour Koffi,'));
      expect(
          koffi.message,
          contains("• Vos créances soldées par d'autres chauffeurs du véhicule : "
              '${montantRecu(50000)}'));
      expect(koffi.message, isNot(contains('Vos cotisations')));
      expect(koffi.message, isNot(contains('Net restitué')));
      expect(koffi.message, isNot(contains('restituée')));
      // Le message seul ne promet pas de pièce jointe.
      expect(koffi.message, isNot(contains('PDF')));
    });

    test('rien à restituer : le message le dit et annonce ce qui reste à payer',
        () {
      // Arrêté par chauffeur : 20 000 de cotisations face à 30 000 de recette.
      final arrete = ArreteCompte(
        id: 13,
        perimetre: 'CHAUFFEUR',
        perimetreId: 3,
        perimetreLibelle: 'Aya Traoré',
        periodeDebut: DateTime(2026, 8, 1),
        periodeFin: DateTime(2026, 8, 31),
        dateArrete: DateTime(2026, 9, 1),
        totalRestitue: 0,
        lignes: const [
          LigneArrete(
              document: 'COTISATION',
              documentId: 1,
              chauffeurId: 3,
              montant: 20000,
              sens: 'CREDIT'),
          LigneArrete(
              document: 'RECETTE',
              documentId: 7,
              chauffeurId: 3,
              montant: 20000,
              sens: 'DEBIT'),
        ],
        reglements: const [
          ReglementArrete(
            chauffeurId: 3,
            chauffeurNom: 'Aya Traoré',
            totalCotisations: 20000,
            totalCreancesCompensees: 20000,
            montantNet: 0,
            reliquatReporte: 10000,
          ),
        ],
      );

      final aya = destinatairesDecompte(arrete, const []).single;

      expect(aya.message,
          contains('• Retenu pour vos créances : ${montantRecu(20000)}'));
      expect(aya.message, contains('Aucune somme ne vous est restituée.'));
      expect(aya.message, contains('Reste à payer : *${montantRecu(10000)}*'));
      expect(aya.message, isNot(contains("d'autres chauffeurs")));
      expect(aya.resume, startsWith('Rien à restituer · reste dû'));
      // Sans véhicule à nommer, le chauffeur tient lieu de plaque.
      expect(nomFichierDecompte(arrete), 'decompte_aya_traore_01-09-2026.pdf');
    });
  });

  test('nom du fichier : la plaque du véhicule, puis le jour de l\'arrêté', () {
    expect(nomFichierDecompte(arreteVehicule()),
        'decompte_1234-AB-01_01-09-2026.pdf');
  });

  group('envoi', () {
    late int demandesPdf;
    late List<String> enregistres;
    late List<(String?, String)> conversations;

    EnvoiDecompte envoi(ArreteCompte arrete,
            {Future<Uint8List> Function()? telecharger}) =>
        EnvoiDecompte(
          arrete: arrete,
          telecharger: telecharger ??
              () async {
                demandesPdf++;
                return pdf;
              },
          ouvrirConversation: (
              {String? telephone, required String message}) async {
            conversations.add((telephone, message));
            return true;
          },
          enregistrerFichier: (octets, nom, mime) async {
            enregistres.add(nom);
            return 'Téléchargements/$nom';
          },
        );

    setUp(() {
      demandesPdf = 0;
      enregistres = [];
      conversations = [];
    });

    test('le PDF n\'est demandé et enregistré qu\'une fois, chaque chauffeur '
        'reçoit son message', () async {
      final arrete = arreteVehicule();
      final envoiDecompte = envoi(arrete);

      for (final destinataire in destinatairesDecompte(arrete, contacts)) {
        expect(await envoiDecompte.envoyer(destinataire), isA<PdfEnregistre>());
      }

      expect(demandesPdf, 1);
      expect(enregistres, ['decompte_1234-AB-01_01-09-2026.pdf']);
      expect(conversations.map((c) => c.$1), ['07 12 34 56 78', '0102030405']);
      expect(conversations.first.$2, contains('Bonjour Aya,'));
      expect(conversations.last.$2, contains('Bonjour Koffi,'));
      // Chaque passage à WhatsApp redit où trouver le fichier à joindre.
      final annonces = appelsNatifs.where((c) => c.method == 'annoncer');
      expect(annonces, hasLength(2));
      expect((annonces.first.arguments as Map)['texte'],
          startsWith('Décompte enregistré dans Téléchargements'));
    });

    test('sans numéro, le PDF part joint et WhatsApp demande le contact',
        () async {
      final arrete = arreteVehicule();
      final koffi = destinatairesDecompte(
          arrete, const [ChauffeurArrete(id: 9, nom: 'Koffi Yao')]).last;

      final issue = await envoi(arrete).envoyer(koffi);

      expect(issue, isA<PdfPartage>());
      final partage = appelsNatifs.single;
      expect(partage.method, 'partagerFichier');
      expect((partage.arguments as Map)['nomFichier'],
          'decompte_1234-AB-01_01-09-2026.pdf');
      expect((partage.arguments as Map)['texte'], contains('Bonjour Koffi,'));
      expect(enregistres, isEmpty);
    });

    test('un PDF refusé ne part pas, et l\'envoi suivant le redemande',
        () async {
      final arrete = arreteVehicule();
      final aya = destinatairesDecompte(arrete, contacts).first;
      var demandes = 0;
      final envoiDecompte = envoi(arrete, telecharger: () async {
        demandes++;
        if (demandes == 1) {
          throw const ApiException(404, 'Arrêté introuvable : 12');
        }
        return pdf;
      });

      expect(
          await envoiDecompte.envoyer(aya),
          isA<PdfIndisponible>()
              .having((i) => i.motif, 'motif', 'Arrêté introuvable : 12'));
      expect(conversations, isEmpty);

      expect(await envoiDecompte.envoyer(aya), isA<PdfEnregistre>());
      expect(demandes, 2);
    });
  });
}
