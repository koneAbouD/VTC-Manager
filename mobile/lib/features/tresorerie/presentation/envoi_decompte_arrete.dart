/// Envoi du décompte d'un arrêté aux chauffeurs qu'il concerne, par WhatsApp.
///
/// Le PDF est le même pour tous — le décompte de l'arrêté entier — mais le
/// message qui l'accompagne parle à chacun de sa part : ses cotisations, ce qui
/// en a été retenu, ce qui lui est versé.
///
/// Sur un arrêté par véhicule, les fonds se mutualisent : le dépôt d'un
/// chauffeur peut solder la dette d'un collègue. Le message le dit dans les deux
/// sens — sans quoi celui dont on a retenu pour autrui croirait avoir dû
/// davantage, et celui qu'on a renfloué ignorerait que sa dette est éteinte. Ce
/// dernier n'a pas de règlement : il ne se lit que dans les lignes, et c'est
/// pourquoi les destinataires ne se déduisent pas des seuls règlements.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/error/exception.dart';
import '../../../core/utils/bytes_downloader.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/envoi_pdf_whatsapp.dart';
import '../../../core/utils/recu_paiement.dart' show montantRecu, nomEntrepriseRecu;
import '../../../core/utils/whatsapp.dart';
import '../../../core/widgets/envoi_recus_sheet.dart' show DestinataireWhatsApp;
import '../domain/entities/compte_courant.dart';

/// Ce que l'arrêté dit à UN chauffeur, lu dans son snapshot.
class PartDecompte {
  /// Son règlement. Nul pour le chauffeur sans dépôt dont un collègue a soldé
  /// la dette : il n'avait rien à arrêter.
  final ReglementArrete? reglement;

  /// Ce que son fonds a éteint sur SES créances.
  final double retenuPourLui;

  /// Ce que son fonds a éteint sur les créances d'autres chauffeurs du véhicule.
  final double retenuPourAutrui;

  /// Ses créances éteintes par le fonds d'autres chauffeurs du véhicule.
  final double soldeParAutrui;

  const PartDecompte._({
    required this.reglement,
    required this.retenuPourLui,
    required this.retenuPourAutrui,
    required this.soldeParAutrui,
  });

  factory PartDecompte.de(ArreteCompte arrete, int chauffeurId) {
    ReglementArrete? reglement;
    for (final r in arrete.reglements) {
      if (r.chauffeurId == chauffeurId) {
        reglement = r;
        break;
      }
    }
    // Une ligne de créance porte son débiteur, jamais le fonds qui l'a payée.
    final sesCreancesEteintes = arrete.lignes
        .where((l) => !l.estCredit && l.chauffeurId == chauffeurId)
        .fold<double>(0, (s, l) => s + l.montant);
    final double retenu = reglement?.totalCreancesCompensees ?? 0;
    // Chacun éteint d'abord ses propres créances et ne finance les autres
    // qu'avec ce qui lui reste. Son fonds a donc couvert les siennes à hauteur
    // de ce qu'il a retenu ; le surplus est allé à autrui, et ce qu'il n'a pas
    // couvert de ses créances éteintes, un collègue l'a payé.
    final pourLui = math.min(retenu, sesCreancesEteintes);
    return PartDecompte._(
      reglement: reglement,
      retenuPourLui: pourLui,
      retenuPourAutrui: retenu - pourLui,
      soldeParAutrui: sesCreancesEteintes - pourLui,
    );
  }

  double get cotisations => reglement?.totalCotisations ?? 0;

  double get net => reglement?.montantNet ?? 0;

  /// Ce qu'il doit encore sur le périmètre de l'arrêté. Nul sans règlement : le
  /// snapshot ne fige pas ce qui restait à celui qui n'avait rien à arrêter.
  double? get resteDu => reglement?.reliquatReporte;
}

/// Un chauffeur à qui envoyer le décompte, et ce que son message lui dira.
class DestinataireDecompte implements DestinataireWhatsApp {
  final int chauffeurId;

  /// Nom complet, prénom en tête. Nul s'il n'est connu nulle part.
  final String? nomComplet;

  @override
  final String? telephone;

  final ArreteCompte arrete;
  final PartDecompte part;

  const DestinataireDecompte({
    required this.chauffeurId,
    this.nomComplet,
    this.telephone,
    required this.arrete,
    required this.part,
  });

  @override
  String get nom => nomComplet ?? 'Chauffeur #$chauffeurId';

  @override
  String get resume {
    if (_significatif(part.net)) {
      return 'Net restitué ${CurrencyFormatter.format(part.net)}';
    }
    final reste = part.resteDu;
    if (reste != null && _significatif(reste)) {
      return 'Rien à restituer · reste dû ${CurrencyFormatter.format(reste)}';
    }
    if (_significatif(part.soldeParAutrui)) {
      return 'Dette soldée par d\'autres chauffeurs · '
          '${CurrencyFormatter.format(part.soldeParAutrui)}';
    }
    return 'Rien à restituer';
  }

  /// Le message seul, sans pièce jointe.
  @override
  String get message => composerDecompte(arrete, nomComplet, part);

  /// Le message qui accompagne le PDF, et le signale.
  String get messageAvecPdf =>
      composerDecompte(arrete, nomComplet, part, avecPieceJointe: true);
}

/// Les chauffeurs que l'arrêté concerne : les bénéficiaires d'abord, dans
/// l'ordre des règlements, puis ceux dont un collègue a soldé la dette.
Set<int> chauffeursConcernes(ArreteCompte arrete) => {
      for (final r in arrete.reglements) r.chauffeurId,
      for (final l in arrete.lignes)
        if (l.chauffeurId != null) l.chauffeurId!,
    };

/// Les destinataires du décompte, un par chauffeur concerné.
///
/// [contacts] porte noms et téléphones, servis à part du détail de l'arrêté.
/// Un chauffeur qui y manque garde le nom de son règlement, sans numéro :
/// WhatsApp demandera alors le contact.
List<DestinataireDecompte> destinatairesDecompte(
    ArreteCompte arrete, List<ChauffeurArrete> contacts) {
  final parId = {for (final c in contacts) c.id: c};
  final nomsReglement = {
    for (final r in arrete.reglements) r.chauffeurId: r.chauffeurNom,
  };
  return [
    for (final id in chauffeursConcernes(arrete))
      DestinataireDecompte(
        chauffeurId: id,
        nomComplet: _premierRenseigne([parId[id]?.nom, nomsReglement[id]]),
        telephone: parId[id]?.telephone,
        arrete: arrete,
        part: PartDecompte.de(arrete, id),
      ),
  ];
}

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Compose le message du décompte pour un chauffeur.
///
/// Mis en forme pour WhatsApp (`*gras*`), montants en FCFA comme sur le PDF.
/// Seuls les montants non nuls sont nommés : un message qui annonce « retenu
/// pour autrui : 0 FCFA » inquiète pour rien.
String composerDecompte(
  ArreteCompte arrete,
  String? nomComplet,
  PartDecompte part, {
  bool avecPieceJointe = false,
}) {
  final prenom = _prenom(nomComplet);
  final corps = <String>[
    prenom == null ? 'Bonjour,' : 'Bonjour $prenom,',
    'voici le décompte de l\'arrêté du '
        '${_dateFmt.format(arrete.dateArrete ?? arrete.periodeFin)}, période du '
        '${_dateFmt.format(arrete.periodeDebut)} au ${_dateFmt.format(arrete.periodeFin)} :',
    if (part.reglement != null)
      '• Vos cotisations : ${montantRecu(part.cotisations)}',
    if (_significatif(part.retenuPourLui))
      '• Retenu pour vos créances : ${montantRecu(part.retenuPourLui)}',
    if (_significatif(part.retenuPourAutrui))
      '• Retenu pour les créances d\'autres chauffeurs du véhicule : '
          '${montantRecu(part.retenuPourAutrui)}',
    if (_significatif(part.soldeParAutrui))
      '• Vos créances soldées par d\'autres chauffeurs du véhicule : '
          '${montantRecu(part.soldeParAutrui)}',
  ];

  final mode = _modeEnPhrase(part.reglement?.modePaiement);
  final reste = part.resteDu;
  final vehicule = _vehicule(arrete);
  final solde = <String>[
    if (_significatif(part.net))
      'Net restitué : *${montantRecu(part.net)}*${mode == null ? '' : ' $mode'}'
    else if (part.reglement != null)
      'Aucune somme ne vous est restituée.',
    // Le reliquat d'un arrêté par véhicule ne compte que les créances de ce
    // véhicule : annoncer « reste à payer » tout court laisserait croire au
    // chauffeur qu'il ne doit rien ailleurs.
    if (reste != null && _significatif(reste))
      arrete.perimetre == 'VEHICULE'
          ? 'Reste à payer sur ce véhicule : *${montantRecu(reste)}*'
          : 'Reste à payer : *${montantRecu(reste)}*',
    if (vehicule != null || _renseigne(arrete.reference))
      [
        if (vehicule != null) 'Véhicule $vehicule',
        if (_renseigne(arrete.reference)) 'Réf. ${arrete.reference!.trim()}',
      ].join(' · '),
  ];

  return [
    ['📄 *Décompte de restitution — $nomEntrepriseRecu*'],
    corps,
    solde,
    if (avecPieceJointe) ['📎 Le décompte détaillé vous est envoyé en PDF.'],
    ['Merci et bonne route !'],
  ].where((bloc) => bloc.isNotEmpty).map((bloc) => bloc.join('\n')).join('\n\n');
}

/// « decompte_1234-AB-01_01-09-2026.pdf » : la plaque du véhicule — le nom du
/// chauffeur, sur un arrêté qui couvre plusieurs véhicules — puis le jour de
/// l'arrêté.
String nomFichierDecompte(ArreteCompte arrete) => nomFichierPdf(
      'decompte',
      vehicule: _vehicule(arrete),
      personne: arrete.perimetre == 'CHAUFFEUR' ? arrete.perimetreLibelle : null,
      jour: arrete.dateArrete ?? arrete.periodeFin,
    );

/// Envoie le décompte d'un arrêté, chauffeur après chauffeur.
///
/// Le PDF est le même pour tous : il n'est demandé qu'une fois au serveur, et
/// enregistré une seule fois sur l'appareil — le guichetier joint le même
/// fichier à chaque conversation, au lieu d'en laisser une copie par chauffeur
/// dans Téléchargements. Un échec ne se retient pas : l'envoi suivant réessaie.
class EnvoiDecompte {
  final ArreteCompte arrete;
  final Future<Uint8List> Function() telecharger;
  final OuvrirConversation ouvrirConversation;
  final EnregistrerFichier enregistrerFichier;

  EnvoiDecompte({
    required this.arrete,
    required this.telecharger,
    this.ouvrirConversation = ouvrirWhatsApp,
    this.enregistrerFichier = downloadBytesFile,
  });

  Future<Uint8List>? _pdf;
  Future<String?>? _enregistrement;

  Future<IssueEnvoiPdf> envoyer(DestinataireDecompte destinataire) async {
    final Uint8List octets;
    try {
      octets = await _pdfUneFois();
    } on ApiException catch (e) {
      return PdfIndisponible(e.message);
    } on NetworkException catch (e) {
      return PdfIndisponible(e.message);
    } catch (_) {
      return const PdfIndisponible('le décompte PDF n\'a pas pu être préparé.');
    }
    return envoyerPdfParWhatsApp(
      octets: octets,
      nomFichier: nomFichierDecompte(arrete),
      message: destinataire.messageAvecPdf,
      document: 'Décompte',
      telephone: destinataire.telephone,
      ouvrirConversation: ouvrirConversation,
      enregistrerFichier: _enregistrerUneFois,
    );
  }

  Future<Uint8List> _pdfUneFois() async {
    final demande = _pdf ??= telecharger();
    try {
      return await demande;
    } catch (_) {
      if (identical(_pdf, demande)) _pdf = null;
      rethrow;
    }
  }

  Future<String?> _enregistrerUneFois(
      Uint8List octets, String nomFichier, String mime) async {
    final enregistrement =
        _enregistrement ??= enregistrerFichier(octets, nomFichier, mime);
    try {
      return await enregistrement;
    } catch (_) {
      if (identical(_enregistrement, enregistrement)) _enregistrement = null;
      rethrow;
    }
  }
}

/// Le véhicule que le décompte nomme : celui de l'arrêté, ou le seul que
/// couvrent les lignes d'un arrêté par chauffeur. Nul s'il y en a plusieurs.
String? _vehicule(ArreteCompte arrete) {
  if (arrete.perimetre == 'VEHICULE' && _renseigne(arrete.perimetreLibelle)) {
    return arrete.perimetreLibelle!.trim();
  }
  final plaques = {
    for (final l in arrete.lignes)
      if (_renseigne(l.immatriculation)) l.immatriculation!.trim(),
  };
  return plaques.length == 1 ? plaques.single : null;
}

bool _renseigne(String? valeur) => valeur != null && valeur.trim().isNotEmpty;

String? _premierRenseigne(List<String?> candidats) {
  for (final candidat in candidats) {
    if (_renseigne(candidat)) return candidat!.trim();
  }
  return null;
}

/// Un montant qui mérite d'être nommé : le franc CFA n'a pas de centimes, et un
/// reste de calcul flottant ne doit pas s'afficher « 0 FCFA ».
bool _significatif(double montant) => montant >= 0.5;

/// Le prénom, premier mot du nom complet (« Aya Traoré » → « Aya »).
String? _prenom(String? nomComplet) {
  if (!_renseigne(nomComplet)) return null;
  return nomComplet!.trim().split(RegExp(r'\s+')).first;
}

String? _modeEnPhrase(String? mode) => switch (mode) {
      'ESPECES' => 'en espèces',
      'MOBILE_MONEY' => 'par Mobile Money',
      _ => null,
    };
