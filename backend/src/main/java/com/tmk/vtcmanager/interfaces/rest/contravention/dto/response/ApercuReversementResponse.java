package com.tmk.vtcmanager.interfaces.rest.contravention.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Aperçu d'une quittance de paiement de l'État importée : en-tête du document et
 * lignes rapprochées avec la base. Rien n'est encore reversé.
 */
@Schema(description = "Aperçu d'une quittance de paiement importée, avant reversement")
public record ApercuReversementResponse(

        @Schema(description = "Numéro de liquidation de la quittance", example = "LIQ-4221283")
        String numeroLiquidation,

        @Schema(description = "Numéro de demande de la quittance", example = "SOL42822489")
        String numeroDemande,

        @Schema(description = "Demandeur (raison sociale)", example = "ABOU-DRAMANE KONE")
        String demandeur,

        @Schema(description = "Date de la quittance", example = "2026-07-03")
        LocalDate dateQuittance,

        @Schema(description = "Clé de l'objet quittance archivé (traçabilité)")
        String documentSourcePath,

        @Schema(description = "Nombre de lignes effectivement reversables", example = "5")
        long nombreAReverser,

        @Schema(description = "Total à reverser (somme des montants système des lignes reversables)",
                example = "40000")
        BigDecimal totalAReverser,

        @Schema(description = "Lignes rapprochées de la quittance")
        List<LigneReversementResponse> lignes
) {}
