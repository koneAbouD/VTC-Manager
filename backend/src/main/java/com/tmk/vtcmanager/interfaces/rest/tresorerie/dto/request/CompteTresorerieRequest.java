package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.request;

import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record CompteTresorerieRequest(
        @NotBlank String code,
        @NotBlank String libelle,
        @NotNull TypeCompteTresorerie type,
        String operateur,
        BigDecimal soldeInitial,
        boolean parDefaut
) {}
