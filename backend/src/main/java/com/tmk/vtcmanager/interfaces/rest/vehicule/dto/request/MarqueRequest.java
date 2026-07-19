package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Requête de création / mise à jour d'une marque (référentiel).
 */
@Schema(description = "Données d'une marque (référentiel de paramétrage).")
public record MarqueRequest(

        @Schema(description = "Nom de la marque. Obligatoire, unique au sein d'un type de véhicule.",
                example = "Toyota", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotBlank(message = "Le nom est obligatoire")
        @Size(max = 100)
        String nom,

        @Schema(description = "Identifiant du type de véhicule rattaché. Obligatoire. "
                + "Source de la liste déroulante : référentiel « types-vehicules ».",
                example = "1", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotNull(message = "Le type de véhicule est obligatoire")
        Long typeId,

        @Schema(description = "Pays d'origine (facultatif).", example = "Japon")
        String paysOrigine
) {}
