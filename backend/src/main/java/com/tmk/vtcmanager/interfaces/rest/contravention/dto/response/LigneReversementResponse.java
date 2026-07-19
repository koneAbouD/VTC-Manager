package com.tmk.vtcmanager.interfaces.rest.contravention.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;

/**
 * Une ligne de quittance rapprochée avec la base, renvoyée dans l'aperçu.
 */
@Schema(description = "Ligne de quittance rapprochée avec une contravention en base")
public record LigneReversementResponse(

        @Schema(description = "Numéro de contravention lu sur la quittance (clé de rapprochement)",
                example = "C0000000000014584852")
        String numeroContravention,

        @Schema(description = "Immatriculation lue sur la ligne", example = "AA-991-SJ-01")
        String plaque,

        @Schema(description = "Code de l'infraction", example = "046")
        String codeInfraction,

        @Schema(description = "Montant réglé à l'État d'après la quittance", example = "10000")
        BigDecimal montantQuittance,

        @Schema(description = "Id de la contravention correspondante en base ; null si introuvable",
                example = "42")
        Long contraventionId,

        @Schema(description = "Montant enregistré côté système ; null si introuvable", example = "10000")
        BigDecimal montantSysteme,

        @Schema(description = "Classement de la ligne",
                allowableValues = {"A_REVERSER", "DEJA_REVERSEE", "INTROUVABLE"}, example = "A_REVERSER")
        String statut,

        @Schema(description = "Vrai si le montant quittance diffère du montant système", example = "false")
        boolean montantDivergent
) {}
