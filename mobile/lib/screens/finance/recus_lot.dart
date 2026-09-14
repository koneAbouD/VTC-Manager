/// Les reçus d'un encaissement de masse : **un par chauffeur**, et non un par
/// journée soldée.
///
/// Un chauffeur qui règle trois journées d'un même versement a reçu un seul
/// argent ; lui envoyer trois messages ferait passer un geste de caisse pour
/// trois paiements. Le reçu détaille donc les journées couvertes, cotisations
/// du même jour comprises, et n'en donne qu'un total.
library;

import 'package:intl/intl.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/recu_paiement.dart';
import '../../core/widgets/encaissement_ligne_dialog.dart'
    show ModeEncaissementSaisie;
import '../../core/widgets/encaissement_lot_dialog.dart';
import '../../core/widgets/envoi_recus_sheet.dart';
import '../../features/recette/domain/entities/ligne_recette.dart';
import 'encaissement_lot_jumele.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Construit les reçus à partir de ce que le lot a réellement encaissé.
///
/// Ce sont les imputations **acceptées** qui font foi, jamais la saisie : une
/// créance refusée — période close, caisse comptée — ne doit apparaître sur
/// aucun reçu.
List<DestinataireRecu> recusDuLot({
  required List<LigneRecette> lignes,
  required Map<int, JumelleLot> jumelles,
  required List<ImputationLot> imputations,
  required SaisieLot saisie,
}) {
  final parLigne = {for (final l in lignes) l.id: l};

  // Regroupement par chauffeur, dans l'ordre où les lignes ont été présentées.
  final parChauffeur = <int, List<ImputationLot>>{};
  for (final imputation in imputations) {
    if (imputation.total <= 0) continue;
    final ligne = parLigne[imputation.ligneId];
    if (ligne == null) continue;
    parChauffeur.putIfAbsent(ligne.chauffeurId, () => []).add(imputation);
  }

  final recus = <DestinataireRecu>[];
  parChauffeur.forEach((chauffeurId, imputationsDuChauffeur) {
    final sesLignes = [
      for (final i in imputationsDuChauffeur) parLigne[i.ligneId]!
    ];
    final premiere = sesLignes.first;

    final lignesRecu = <LigneRecu>[];
    for (final imputation in imputationsDuChauffeur) {
      final ligne = parLigne[imputation.ligneId]!;
      final jour = _dateFmt.format(ligne.dateRecette);
      if (imputation.principal > 0) {
        lignesRecu.add(
            LigneRecu(libelle: 'Recette du $jour', montant: imputation.principal));
      }
      if (imputation.jumelle > 0) {
        final nom = jumelles[ligne.id]?.libelle ?? 'Cotisation';
        lignesRecu
            .add(LigneRecu(libelle: '$nom du $jour', montant: imputation.jumelle));
      }
    }
    if (lignesRecu.isEmpty) return;

    // Le véhicule n'est nommé que s'il est le même partout : un chauffeur qui a
    // tourné sur deux voitures dans la période ne doit pas en voir une seule.
    final immatriculations =
        sesLignes.map((l) => l.vehiculeImmatriculation).toSet();

    final total = lignesRecu.fold<double>(0, (t, l) => t + l.montant);
    final resteDu =
        imputationsDuChauffeur.fold<double>(0, (t, i) => t + i.restant);

    final journees = imputationsDuChauffeur.length;
    recus.add(DestinataireRecu(
      nom: premiere.chauffeurNom ?? 'Chauffeur #$chauffeurId',
      telephone: premiere.chauffeurTelephone,
      resume: '$journees journée${journees > 1 ? 's' : ''} · '
          '${CurrencyFormatter.format(total)}',
      recu: RecuPaiement(
        chauffeur: premiere.chauffeurNom,
        vehicule: immatriculations.length == 1 ? immatriculations.first : null,
        lignes: lignesRecu,
        modePaiement: saisie.mode == ModeEncaissementSaisie.mobileMoney
            ? 'Mobile Money'
            : 'Espèces',
        date: saisie.date,
        reference: saisie.reference,
        resteDu: resteDu,
      ),
      // Toutes les écritures du chauffeur dans le lot : son reçu PDF les
      // atteste ensemble.
      operationIds: [
        for (final imputation in imputationsDuChauffeur)
          ...imputation.operationIds,
      ],
    ));
  });

  return recus;
}
