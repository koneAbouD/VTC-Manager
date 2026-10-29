package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/**
 * Requête de création / mise à jour d'un élément de catalogue de maintenance.
 * Libellé et type valent pour tous les modèles ; le modèle, le prix et l'image
 * ne servent qu'à la création, pour créer d'emblée le tarif de ce modèle.
 */
@Schema(description = "Données d'un élément de catalogue de maintenance (référentiel de paramétrage).")
public record CatalogueElementMaintenanceRequest(
        @Schema(description = "Libellé de l'élément de maintenance. Obligatoire, unique.",
                example = "Filtre à huile", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotBlank(message = "Le libellé est obligatoire")
        @Size(max = 255)
        String libelle,

        @Schema(description = "Type de maintenance (catégorie de la sous-catégorie « Maintenances ») "
                + "auquel l'élément est réservé (facultatif : sans type, l'élément est proposé "
                + "pour tous les types).", nullable = true)
        Long categorieTypeId,

        @Schema(description = "Création seulement : modèle de véhicule pour lequel créer le tarif "
                + "de l'élément.", nullable = true)
        Long modeleId,

        @Schema(description = "Création seulement : prix de l'élément pour ce modèle (facultatif).",
                example = "15000", nullable = true)
        @PositiveOrZero(message = "Le prix ne peut pas être négatif")
        BigDecimal prix,

        @Schema(description = "Création seulement : nom d'objet de l'image pour ce modèle "
                + "(retourné par POST /image ; facultatif).", nullable = true)
        @Size(max = 512)
        String image
) {}
