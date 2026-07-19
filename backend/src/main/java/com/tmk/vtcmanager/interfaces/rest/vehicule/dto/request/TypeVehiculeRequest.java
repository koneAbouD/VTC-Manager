package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Requête de création / mise à jour d'un type de véhicule (référentiel).
 */
@Schema(description = "Données d'un type de véhicule (référentiel de paramétrage).")
public record TypeVehiculeRequest(

        @Schema(description = "Nom du type de véhicule. Obligatoire, unique.",
                example = "TAXI", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotBlank(message = "Le nom est obligatoire")
        @Size(max = 100)
        String nom,

        @Schema(description = "Description libre (facultatif).", example = "Véhicule de transport de personnes")
        String description
) {}
