import 'package:intl/intl.dart';

import '../../../core/utils/recu_paiement.dart';
import '../../operation_financiere/domain/enums/mode_paiement.dart';
import '../domain/entities/versement.dart';

final _jour = DateFormat('dd/MM/yyyy');

/// Le reçu d'un versement entier : la recette et la cotisation du jour sur un
/// seul message, avec ce qui reste dû sur les deux créances.
///
/// Chaque créance y est nommée comme le chauffeur la connaît — « Recette »,
/// « Cotisation carburant » — à la journée réglée, pas au jour du versement.
/// Une imputation extournée n'y figure pas : le billet ne l'atteste plus.
RecuPaiement recuDuVersement(Versement versement) {
  final actives = versement.actives;
  return RecuPaiement(
    chauffeur: versement.chauffeurNom,
    vehicule: versement.vehiculeImmatriculation,
    lignes: [
      for (final i in actives)
        LigneRecu(
          libelle: '${i.libelle ?? 'Versement'} du '
              '${_jour.format(i.dateReference ?? versement.dateEncaissement)}',
          montant: i.montant,
        ),
    ],
    modePaiement: versement.modePaiement?.libelle,
    date: versement.dateEncaissement,
    reference: actives.isEmpty ? null : actives.first.reference,
    resteDu: versement.resteDu,
  );
}
