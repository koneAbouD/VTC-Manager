package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Requête de création / mise à jour d'une balise GPS (référentiel).
 */
@Schema(description = "Données d'une balise GPS (référentiel de paramétrage).")
public record BaliseRequest(

        @Schema(description = "Identifiant de la balise. Obligatoire, unique.",
                example = "BAL-00123", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotBlank(message = "L'identifiant est obligatoire")
        @Size(max = 100)
        String identifiant,

        @Schema(description = "Numéro de téléphone de la carte SIM de la balise (facultatif).",
                example = "06 12 34 56 78")
        @Size(max = 30)
        String numeroTelephone
) {}
