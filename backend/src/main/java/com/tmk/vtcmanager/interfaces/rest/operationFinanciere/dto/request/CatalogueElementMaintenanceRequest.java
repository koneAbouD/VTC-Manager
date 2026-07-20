package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/**
 * Requête de création / mise à jour d'un élément de catalogue de maintenance.
 */
@Schema(description = "Données d'un élément de catalogue de maintenance (référentiel de paramétrage).")
public record CatalogueElementMaintenanceRequest(

        @Schema(description = "Libellé de l'élément de maintenance. Obligatoire, unique.",
                example = "Vidange moteur", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotBlank(message = "Le libellé est obligatoire")
        @Size(max = 255)
        String libelle,

        @Schema(description = "Montant par défaut pré-rempli à la saisie (facultatif).", example = "15000")
        @PositiveOrZero(message = "Le montant par défaut ne peut pas être négatif")
        BigDecimal montantDefaut,

        @Schema(description = "Nom d'objet de l'image d'illustration dans le stockage "
                + "(retourné par POST /image ; facultatif).", nullable = true)
        @Size(max = 512)
        String image
) {}
