/// Le reçu qu'un chauffeur reçoit après avoir versé : ce qu'il a payé, pour
/// quelles journées, et ce qu'il doit encore.
///
/// Rédigé pour être lu d'un coup d'œil sur un téléphone : le montant reçu en
/// premier et en gras, la ventilation ensuite, le solde pour finir. Les
/// montants sont en FCFA — la monnaie que le chauffeur lit sur ses billets, et
/// celle des documents PDF de l'application. La mise en forme suit celle de
/// WhatsApp (`*gras*`).
///
/// Ce fichier ne fait que composer une chaîne : aucun accès réseau, aucun
/// contexte Flutter.
library;

import 'package:intl/intl.dart';

/// Nom qui signe le reçu. Seul endroit à changer si l'entreprise change de
/// nom ; le PDF, rendu par le serveur, porte la même signature.
const String nomEntrepriseRecu = 'TMK';

/// Une créance soldée par le versement — une journée de recette, la cotisation
/// du même jour.
class LigneRecu {
  final String libelle;
  final double montant;

  const LigneRecu({required this.libelle, required this.montant});
}

/// De quoi rédiger le reçu d'un versement, qu'il solde une seule journée ou
/// plusieurs d'un même geste de caisse.
class RecuPaiement {
  /// Nom complet, prénom en tête : c'est lui qui salue le chauffeur.
  final String? chauffeur;
  final String? vehicule;

  /// Ce que le versement a soldé. Une seule ligne : le reçu la nomme ;
  /// plusieurs : il les détaille, montant par montant.
  final List<LigneRecu> lignes;

  /// Null quand l'écriture n'en porte pas : le reçu se tait plutôt que
  /// d'affirmer des espèces qui n'ont peut-être pas été versées.
  final String? modePaiement;
  final DateTime date;
  final String? reference;

  /// Ce qui reste à payer sur la recette et la cotisation du jour réglé — et
  /// seulement celles-là. Null quand le montant n'est pas connu — une recette
  /// au réel n'a pas de dû d'avance — auquel cas le reçu n'en dit rien plutôt
  /// que d'annoncer un solde faux.
  final double? resteDu;

  /// Le total des créances du chauffeur — recettes, pénalités et cotisations
  /// échues (ni annulées ni restituées), hors contraventions — calculé par le
  /// serveur. Avec [resteDu], c'est lui qui permet de dire « à jour » : solder une
  /// journée ne solde pas les autres. Null quand il n'est pas connu — le reçu
  /// ne dit alors jamais « à jour ».
  final double? detteTotale;

  /// En service, le chauffeur roule aujourd'hui (vrai) ou c'est son tour de
  /// repos (faux) ; nul pour tout autre statut ou quand le serveur ne l'a pas
  /// dit. Il choisit le mot de la fin : bonne route, bon repos, ou merci seul.
  final bool? auVolant;

  const RecuPaiement({
    this.chauffeur,
    this.vehicule,
    required this.lignes,
    this.modePaiement,
    required this.date,
    this.reference,
    this.resteDu,
    this.detteTotale,
    this.auVolant,
  });

  /// Le même reçu, avec ce que le serveur sait du chauffeur aujourd'hui : le
  /// reste du jour, le total de ses créances et s'il roule. Le reste du jour
  /// du serveur prime : il compte aussi la créance du jour que le versement
  /// n'a pas touchée.
  RecuPaiement avecSituation(
          {double? resteDu, double? detteTotale, bool? auVolant}) =>
      RecuPaiement(
        chauffeur: chauffeur,
        vehicule: vehicule,
        lignes: lignes,
        modePaiement: modePaiement,
        date: date,
        reference: reference,
        resteDu: resteDu ?? this.resteDu,
        detteTotale: detteTotale,
        auVolant: auVolant,
      );

  double get total => lignes.fold(0, (t, l) => t + l.montant);
}

final _dateFmt = DateFormat('dd/MM/yyyy');
final _montantFmt = NumberFormat('#,##0', 'fr_FR');

/// Un montant tel que le reçu l'écrit : « 15 000 FCFA ».
String montantRecu(double montant) => '${_montantFmt.format(montant)} FCFA';

/// Compose le message du reçu.
///
/// [avecPieceJointe] : le message accompagne le reçu PDF — en légende, ou juste
/// avant lui dans la conversation — et le signale. Les
/// champs absents sont omis — un reçu qui annonce « Véhicule : null »
/// décrédibilise le versement qu'il atteste.
String composerRecu(RecuPaiement recu, {bool avecPieceJointe = false}) {
  final prenom = _prenom(recu.chauffeur);
  final mode = _modeEnPhrase(recu.modePaiement);
  final reception = [
    'nous avons bien reçu *${montantRecu(recu.total)}*',
    'le ${_dateFmt.format(recu.date)}',
    if (mode != null) mode,
  ].join(' ');

  // Une seule créance : le montant est déjà dit, on la nomme. Plusieurs : le
  // chauffeur doit voir quelles journées sont couvertes, et pour combien.
  final corps = <String>[
    prenom == null ? 'Bonjour,' : 'Bonjour $prenom,',
    if (recu.lignes.length == 1) ...[
      '$reception.',
      '• ${recu.lignes.single.libelle}',
    ] else ...[
      '$reception :',
      for (final ligne in recu.lignes)
        '• ${ligne.libelle} : ${montantRecu(ligne.montant)}',
    ],
  ];

  final ligneReste = _ligneResteDuJour(recu);
  final solde = <String>[
    if (ligneReste != null) ligneReste,
    if (_renseigne(recu.vehicule) || _renseigne(recu.reference))
      [
        if (_renseigne(recu.vehicule)) 'Véhicule ${recu.vehicule!.trim()}',
        if (_renseigne(recu.reference)) 'Réf. ${recu.reference!.trim()}',
      ].join(' · '),
  ];

  return [
    ['✅ *Paiement reçu — $nomEntrepriseRecu*'],
    corps,
    solde,
    if (_ligneCreances(recu) case final creances?) [creances],
    if (avecPieceJointe) ['📎 Le reçu détaillé vous est envoyé en PDF.'],
    [_motDeLaFin(recu.auVolant)],
  ].where((bloc) => bloc.isNotEmpty).map((bloc) => bloc.join('\n')).join('\n\n');
}

/// Le reste à payer sur la recette et la cotisation du jour, seulement : les
/// autres journées se disent dans le total des créances. Rien quand ce reste
/// est soldé ou inconnu.
String? _ligneResteDuJour(RecuPaiement recu) {
  final reste = recu.resteDu;
  if (reste == null || reste <= 0) return null;
  return 'Reste à payer (recette et cotisation du jour) : '
      '*${montantRecu(reste)}*';
}

/// Le rappel du total des créances du chauffeur, en paragraphe à part. « À
/// jour » seulement quand il est nul et que le jour est soldé ; inconnu, il
/// se tait — on ne peut rien affirmer.
String? _ligneCreances(RecuPaiement recu) {
  final total = recu.detteTotale;
  if (total == null) return null;
  if (total > 0) {
    return '📌 Total de vos créances à ce jour : *${montantRecu(total)}*';
  }
  final reste = recu.resteDu;
  return reste == null || reste <= 0
      ? 'Vous êtes à jour.'
      : 'Aucune autre créance en cours.';
}

/// « Bonne route » à qui roule aujourd'hui, « bon repos » à qui est de repos ;
/// à tout autre — en congé, sans véhicule, ou inconnu — un merci seul.
String _motDeLaFin(bool? auVolant) => switch (auVolant) {
      true => 'Merci et bonne route !',
      false => 'Merci et bon repos !',
      null => 'Merci !',
    };

bool _renseigne(String? valeur) => valeur != null && valeur.trim().isNotEmpty;

/// Le prénom, premier mot du nom complet (« Jean Kouassi » → « Jean »).
String? _prenom(String? nomComplet) {
  if (!_renseigne(nomComplet)) return null;
  return nomComplet!.trim().split(RegExp(r'\s+')).first;
}

/// « en espèces », « par Mobile Money » : le mode lu dans la phrase.
String? _modeEnPhrase(String? mode) {
  if (!_renseigne(mode)) return null;
  final m = mode!.trim();
  return m.toLowerCase().contains('esp') ? 'en espèces' : 'par $m';
}
