package com.tmk.vtcmanager.interfaces.rest.partenaire.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Requête de création / mise à jour d'un type de partenaire (référentiel). */
@Schema(description = "Données d'un type de partenaire (référentiel de paramétrage).")
public record TypePartenaireRequest(

        @Schema(description = "Nom du type de partenaire. Obligatoire, unique.",
                example = "Prestataire", requiredMode = Schema.RequiredMode.REQUIRED)
        @NotBlank(message = "Le nom est obligatoire")
        @Size(max = 100)
        String nom,

        @Schema(description = "Description libre (facultatif).",
                example = "Garage, mécanicien, lavage — une prestation de service.")
        @Size(max = 255)
        String description
) {}
