package com.tmk.vtcmanager.interfaces.rest.contravention.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * Bilan renvoyé après confirmation d'un reversement par quittance.
 */
@Schema(description = "Bilan d'une confirmation de reversement par quittance")
public record ResultatReversementResponse(

        @Schema(description = "Nombre de contraventions effectivement reversées", example = "5")
        int reversees,

        @Schema(description = "Nombre ignorées car déjà reversées (idempotence)", example = "0")
        int dejaReversees,

        @Schema(description = "Nombre ignorées (id introuvable ou non sélectionnable)", example = "0")
        int ignorees
) {}
