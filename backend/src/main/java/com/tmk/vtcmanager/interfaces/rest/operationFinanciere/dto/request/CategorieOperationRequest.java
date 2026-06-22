package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record CategorieOperationRequest(
        @NotBlank String code,
        @NotBlank String libelle,
        @NotNull TypeOperation typeOperation
) {}
