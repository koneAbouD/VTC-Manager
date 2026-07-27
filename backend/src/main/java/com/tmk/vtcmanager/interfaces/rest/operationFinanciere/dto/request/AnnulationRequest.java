package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Motif de l'annulation d'une écriture. Obligatoire : la contre-passation reste
 * au journal, elle doit dire pourquoi elle existe.
 */
public record AnnulationRequest(
        @NotBlank(message = "Le motif d'annulation est obligatoire")
        @Size(max = 500, message = "Le motif ne peut pas dépasser 500 caractères")
        String motif
) {
}
