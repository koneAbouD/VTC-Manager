package com.tmk.vtcmanager.interfaces.rest.maintenance.dto.request;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;

import java.math.BigDecimal;
import java.time.LocalDate;

public record CompleteMaintenanceRequest(
        BigDecimal cout,
        LocalDate dateEffectuee,
        ModePaiement modePaiement,
        Long categorieId,
        Long sousCategorieId
) {
    public LocalDate dateEffectueeOrToday() {
        return dateEffectuee != null ? dateEffectuee : LocalDate.now();
    }

    public ModePaiement modePaiementOrDefault() {
        return modePaiement != null ? modePaiement : ModePaiement.ESPECES;
    }
}