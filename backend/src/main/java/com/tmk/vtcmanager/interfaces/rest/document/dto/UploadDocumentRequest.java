package com.tmk.vtcmanager.interfaces.rest.document.dto;

import com.tmk.vtcmanager.application.domain.chauffeur.TypePermis;
import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.Set;

public record UploadDocumentRequest(
        @NotNull Long typeDocumentId,
        @NotNull CibleDocument cible,
        @NotNull Long cibleId,
        @NotBlank String reference,
        LocalDate dateEmission,
        LocalDate dateExpiration,
        Set<TypePermis> categorie,
        Boolean permanence
) {}
