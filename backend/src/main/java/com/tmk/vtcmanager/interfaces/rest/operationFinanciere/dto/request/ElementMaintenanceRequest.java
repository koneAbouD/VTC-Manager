package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;

public record ElementMaintenanceRequest(
        Long catalogueElementId,
        String libelle,
        @NotNull @Positive BigDecimal montant
) {}
