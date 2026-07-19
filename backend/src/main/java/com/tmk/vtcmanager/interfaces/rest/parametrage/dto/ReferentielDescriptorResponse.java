package com.tmk.vtcmanager.interfaces.rest.parametrage.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/**
 * Description d'un référentiel paramétrable. L'écran générique de paramétrage
 * du front construit à partir de cette description la liste, le formulaire et
 * les appels REST (via {@code endpoint}) — sans page codée en dur.
 */
@Schema(description = "Métadonnées d'un référentiel paramétrable.")
public record ReferentielDescriptorResponse(

        @Schema(description = "Clé technique unique du référentiel.", example = "types-vehicules")
        String key,

        @Schema(description = "Libellé affiché (titre de la section).", example = "Types de véhicule")
        String libelle,

        @Schema(description = "Courte description de ce que contient le référentiel.",
                example = "Catégories de véhicules (TAXI, LIVRAISON, …).")
        String description,

        @Schema(description = "Base d'URL REST du référentiel.", example = "/api/v1/types-vehicules")
        String endpoint,

        @Schema(description = "Référentiel modifiable (création/édition/désactivation). "
                + "false = lecture seule (ex. enums de code).", example = "true")
        boolean editable,

        @Schema(description = "Nom du champ identifiant utilisé dans les URLs {id}.", example = "id")
        String idField,

        @Schema(description = "Schéma des champs du référentiel.")
        List<ChampDescriptorResponse> champs
) {}
