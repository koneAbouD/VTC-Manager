package com.tmk.vtcmanager.interfaces.rest.document.dto;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record TypeDocumentRequest(
        @NotBlank String nom,
        @NotNull CibleDocument cible,
        boolean obligatoire
) {}