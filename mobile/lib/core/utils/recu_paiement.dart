/// Le reçu qu'un chauffeur reçoit après avoir versé : ce qu'il a payé, pour
/// quelles journées, et ce qu'il doit encore.
///
/// Le reçu voyage en **texte** : WhatsApp n'accepte pas de pièce jointe par
/// lien, et un message lisible d'un coup d'œil vaut mieux, sur le terrain,
/// qu'un PDF à ouvrir. La mise en forme suit celle de WhatsApp — `*gras*`.
///
/// Ce fichier ne fait que composer une chaîne : aucun accès réseau, aucun
/// contexte Flutter. L'envoi proprement dit est dans `whatsapp.dart`.
library;

import 'package:intl/intl.dart';

import 'currency_formatter.dart';

/// Nom qui coiffe le reçu. Seul endroit à changer si l'entreprise change de
/// nom ou si l'application sert un autre exploitant.
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
  final String? chauffeur;
  final String? vehicule;

  /// Ce que le versement a soldé. Une seule ligne : le reçu annonce un
  /// montant ; plusieurs : il les détaille puis en donne le total.
  final List<LigneRecu> lignes;

  /// Null quand l'écriture n'en porte pas : le reçu se tait plutôt que
  /// d'affirmer des espèces qui n'ont peut-être pas été versées.
  final String? modePaiement;
  final DateTime date;
  final String? reference;

  /// Ce qui reste dû après ce versement. Null quand le montant n'est pas
  /// connu — une recette au réel n'a pas de dû d'avance — auquel cas le reçu
  /// n'en dit rien plutôt que d'annoncer un solde faux.
  final double? resteDu;

  const RecuPaiement({
    this.chauffeur,
    this.vehicule,
    required this.lignes,
    this.modePaiement,
    required this.date,
    this.reference,
    this.resteDu,
  });

  double get total => lignes.fold(0, (t, l) => t + l.montant);
}

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Compose le message du reçu. Les champs vides sont omis : un reçu qui
/// annonce « Véhicule : null » décrédibilise le versement qu'il atteste.
String composerRecu(RecuPaiement recu) {
  final lignes = <String>[
    '*REÇU DE PAIEMENT*',
    nomEntrepriseRecu,
    '',
  ];

  if (recu.chauffeur != null && recu.chauffeur!.trim().isNotEmpty) {
    lignes.add('Chauffeur : ${recu.chauffeur!.trim()}');
  }
  if (recu.vehicule != null && recu.vehicule!.trim().isNotEmpty) {
    lignes.add('Véhicule : ${recu.vehicule!.trim()}');
  }
  if (lignes.last.isNotEmpty) lignes.add('');

  // Une seule créance soldée se lit mieux en une ligne ; plusieurs méritent le
  // détail, sans quoi le chauffeur ne sait pas quelles journées sont couvertes.
  if (recu.lignes.length == 1) {
    lignes.add(recu.lignes.single.libelle);
    lignes.add('*Montant reçu : ${CurrencyFormatter.format(recu.total)}*');
  } else {
    for (final l in recu.lignes) {
      lignes.add('• ${l.libelle} : ${CurrencyFormatter.format(l.montant)}');
    }
    lignes.add('*Total reçu : ${CurrencyFormatter.format(recu.total)}*');
  }

  lignes.add('');
  if (recu.modePaiement != null && recu.modePaiement!.trim().isNotEmpty) {
    lignes.add('Mode : ${recu.modePaiement!.trim()}');
  }
  lignes.add('Date : ${_dateFmt.format(recu.date)}');

  if (recu.reference != null && recu.reference!.trim().isNotEmpty) {
    lignes.add('Réf. : ${recu.reference!.trim()}');
  }

  if (recu.resteDu != null) {
    lignes.add('');
    lignes.add(recu.resteDu! <= 0
        ? 'Solde : à jour'
        : 'Reste dû : ${CurrencyFormatter.format(recu.resteDu!)}');
  }

  lignes
    ..add('')
    ..add('Merci.');

  return lignes.join('\n');
}
