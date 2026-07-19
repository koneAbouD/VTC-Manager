package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Requête de création / mise à jour d'un type d'activité (référentiel).
 */
@Schema(description = "Données d'un type d'activité (référentiel de paramétrage).")
public record TypeActiviteRequest(

        @Schema(description = "Nom du type d'activité. Obligatoire, unique.",
                example = "VTC", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotBlank(message = "Le nom est obligatoire")
        @Size(max = 100)
        String nom,

        @Schema(description = "Description libre (facultatif).", example = "Transport de personnes avec chauffeur")
        String description
) {}
