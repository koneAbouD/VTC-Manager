package com.tmk.vtcmanager.interfaces.rest.common;

import jakarta.validation.constraints.NotBlank;

/** Corps de requête pour l'annulation d'une ligne : motif obligatoire. */
public record AnnulationRequest(
        @NotBlank(message = "Le motif d'annulation est obligatoire.") String motif
) {}
