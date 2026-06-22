package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

import com.tmk.vtcmanager.application.domain.operation.TypeOperation;

public record CategorieOperationResponse(
        Long id,
        String code,
        String libelle,
        TypeOperation typeOperation,
        boolean actif,
        SousCategorieOperationResponse sousCategorie
) {}
