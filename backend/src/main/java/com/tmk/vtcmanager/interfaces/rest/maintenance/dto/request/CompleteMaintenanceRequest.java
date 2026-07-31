package com.tmk.vtcmanager.interfaces.rest.maintenance.dto.request;

import com.tmk.vtcmanager.application.domain.maintenance.ReglementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Clôture d'une intervention.
 *
 * <p>{@code aCredit} décide de tout : réglée comptant, l'intervention produit
 * une dépense payée ; laissée à payer, elle fait naître une dette envers ses
 * partenaires, exigible à {@code dateEcheance}.
 */
public record CompleteMaintenanceRequest(
        BigDecimal cout,
        LocalDate dateEffectuee,
        ModePaiement modePaiement,
        Long categorieId,
        Long sousCategorieId,
        /** Vrai si l'intervention reste due : dette partenaire au lieu d'un paiement. */
        Boolean aCredit,
        /** Échéance de la dette ; à défaut, due à réception. */
        LocalDate dateEcheance
) {
    public LocalDate dateEffectueeOrToday() {
        return dateEffectuee != null ? dateEffectuee : LocalDate.now();
    }

    public ModePaiement modePaiementOrDefault() {
        return modePaiement != null ? modePaiement : ModePaiement.ESPECES;
    }

    public ReglementMaintenance reglement() {
        return Boolean.TRUE.equals(aCredit)
                ? ReglementMaintenance.aCredit(dateEcheance)
                : ReglementMaintenance.comptant(modePaiement);
    }
}
