package com.tmk.vtcmanager.interfaces.rest.common;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/** Correction du montant dû d'une recette ou d'une amende, toujours motivée. */
public record ModificationMontantRequest(
        @NotNull @Positive BigDecimal montant,
        @NotBlank @Size(max = 500) String motif
) {}
