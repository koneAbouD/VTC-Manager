package com.tmk.vtcmanager.application.ports.extraction;

import java.math.BigDecimal;

/**
 * Une ligne de la quittance de paiement délivrée par l'État (QuiPux / DGI),
 * telle qu'extraite du document, avant rapprochement avec les contraventions en
 * base. La clé de rapprochement est {@link #numeroContravention()} (« C » suivi
 * d'au moins 15 chiffres), identique au numéro de relevé stocké côté système.
 *
 * @param numeroContravention numéro de contravention (colonne « No.Contravention »)
 * @param plaque              immatriculation lue sur la ligne (peut être nulle)
 * @param codeInfraction      code de l'infraction (ex. « 045 », « 046 »)
 * @param montant             montant réglé à l'État (colonne « Montant à ce jour »)
 */
public record LigneQuittanceReversement(
        String numeroContravention,
        String plaque,
        String codeInfraction,
        BigDecimal montant
) {}
