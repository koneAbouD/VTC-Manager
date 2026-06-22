package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

import java.math.BigDecimal;

public record ElementMaintenanceResponse(
        Long id,
        CatalogueElementMaintenanceResponse catalogueElement,
        String libelle,
        BigDecimal montant
) {}
