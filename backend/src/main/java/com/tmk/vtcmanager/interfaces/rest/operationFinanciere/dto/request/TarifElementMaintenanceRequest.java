package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

@Schema(description = "Prix, image et activation d'un élément de maintenance pour un modèle de véhicule.")
public record TarifElementMaintenanceRequest(
        @Schema(description = "Prix pour ce modèle (facultatif).", example = "15000", nullable = true)
        @PositiveOrZero(message = "Le prix ne peut pas être négatif")
        BigDecimal prix,

        @Schema(description = "Nom d'objet de l'image pour ce modèle (retourné par POST /image ; facultatif).",
                nullable = true)
        @Size(max = 512)
        String image,

        @Schema(description = "Proposé ou non pour ce modèle. Absent : proposé.", nullable = true)
        Boolean actif
) {}
