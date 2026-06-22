package com.tmk.vtcmanager.interfaces.rest.document.dto;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;

public record TypeDocumentResponse(
        Long id,
        String nom,
        CibleDocument cible,
        boolean obligatoire
) {}