package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Requête de création / mise à jour d'un élément de catalogue de maintenance.
 */
@Schema(description = "Données d'un élément de catalogue de maintenance (référentiel de paramétrage).")
public record CatalogueElementMaintenanceRequest(

        @Schema(description = "Libellé de l'élément de maintenance. Obligatoire, unique.",
                example = "Vidange moteur", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotBlank(message = "Le libellé est obligatoire")
        @Size(max = 255)
        String libelle
) {}
