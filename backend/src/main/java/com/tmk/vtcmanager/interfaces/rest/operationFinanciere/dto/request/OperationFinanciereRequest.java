package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;

public record OperationFinanciereRequest(
        @NotNull TypeOperation typeOperation,
        @NotNull Long categorieId,
        Long sousCategorieId,
        Long chauffeurId,
        Long vehiculeId,
        BigDecimal montant,
        @NotNull ModePaiement modePaiement,
        @NotNull LocalDate dateOperation,
        String commentaire,
        @Valid DetailMaintenanceRequest detailMaintenance
) {}
