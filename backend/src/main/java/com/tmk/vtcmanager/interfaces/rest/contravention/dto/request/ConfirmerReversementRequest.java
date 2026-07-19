package com.tmk.vtcmanager.interfaces.rest.contravention.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

/**
 * Requête de confirmation de reversement par quittance : les contraventions
 * retenues par l'exploitant et la référence de la quittance (traçabilité).
 */
@Schema(description = "Confirmation de reversement des contraventions d'une quittance")
public record ConfirmerReversementRequest(

        @Schema(description = "Référence de la quittance tracée sur les opérations de dépense "
                + "(n° de liquidation, à défaut n° de demande)", example = "LIQ-4221283")
        String referenceQuittance,

        @Schema(description = "Ids des contraventions à reverser (lignes A_REVERSER cochées)",
                requiredMode = Schema.RequiredMode.REQUIRED, example = "[42, 43, 44]")
        @NotEmpty(message = "Au moins une contravention doit être sélectionnée")
        List<Long> contraventionIds
) {}
