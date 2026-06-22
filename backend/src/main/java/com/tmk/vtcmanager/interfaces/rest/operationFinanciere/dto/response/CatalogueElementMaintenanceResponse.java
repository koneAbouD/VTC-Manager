package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

public record CatalogueElementMaintenanceResponse(
        Long id,
        String libelle,
        boolean actif
) {}
