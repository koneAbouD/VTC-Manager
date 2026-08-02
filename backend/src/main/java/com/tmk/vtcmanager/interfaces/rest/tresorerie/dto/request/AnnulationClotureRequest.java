package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.request;

import jakarta.validation.constraints.NotBlank;

/** Retrait d'un relevé erroné : le motif reste au dossier avec lui. */
public record AnnulationClotureRequest(
        @NotBlank String motif
) {}
