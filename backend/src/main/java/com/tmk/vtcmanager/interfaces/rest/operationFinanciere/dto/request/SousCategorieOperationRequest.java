package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import jakarta.validation.constraints.NotBlank;

public record SousCategorieOperationRequest(
        @NotBlank String code,
        @NotBlank String libelle
) {}
