package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Requête de création / mise à jour d'un modèle (référentiel). Le type de
 * véhicule est déduit de la marque rattachée.
 */
@Schema(description = "Données d'un modèle (référentiel de paramétrage).")
public record ModeleRequest(

        @Schema(description = "Nom du modèle. Obligatoire.",
                example = "Corolla", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotBlank(message = "Le nom est obligatoire")
        @Size(max = 100)
        String nom,

        @Schema(description = "Identifiant de la marque rattachée. Obligatoire. "
                + "Source de la liste déroulante : référentiel « marques ».",
                example = "1", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotNull(message = "La marque est obligatoire")
        Long marqueId
) {}
