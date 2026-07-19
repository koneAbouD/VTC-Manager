package com.tmk.vtcmanager.application.ports.extraction;

import java.time.LocalDate;
import java.util.List;

/**
 * Résultat de l'extraction d'une quittance de paiement de l'État : l'en-tête
 * (numéros de liquidation / demande, demandeur, date) et les lignes réglées.
 *
 * @param numeroLiquidation numéro de liquidation (ex. « LIQ-4221283 »)
 * @param numeroDemande     numéro de demande (ex. « SOL42822489 »)
 * @param demandeur         raison sociale / nom du demandeur
 * @param dateQuittance     date de la quittance (peut être nulle)
 * @param lignes            contraventions réglées ; liste vide si aucune trouvée
 */
public record QuittanceReversement(
        String numeroLiquidation,
        String numeroDemande,
        String demandeur,
        LocalDate dateQuittance,
        List<LigneQuittanceReversement> lignes
) {

    /** Référence d'audit compacte : n° de liquidation à défaut n° de demande. */
    public String referenceAudit() {
        if (numeroLiquidation != null && !numeroLiquidation.isBlank()) {
            return numeroLiquidation;
        }
        return numeroDemande;
    }
}
