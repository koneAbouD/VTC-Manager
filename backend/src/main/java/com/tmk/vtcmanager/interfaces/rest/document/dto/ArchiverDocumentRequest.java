package com.tmk.vtcmanager.interfaces.rest.document.dto;

import jakarta.validation.constraints.NotBlank;

public record ArchiverDocumentRequest(
        @NotBlank String raisonArchivage
) {}