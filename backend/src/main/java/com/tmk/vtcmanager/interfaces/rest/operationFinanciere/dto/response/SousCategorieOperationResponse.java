package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

public record SousCategorieOperationResponse(
        Long id,
        String code,
        String libelle,
        Long categorieId,
        boolean actif
) {}
