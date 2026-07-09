package com.tmk.vtcmanager.interfaces.rest.contravention.dto.request;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;

/**
 * Une contravention issue de l'aperçu, révisée par l'exploitant avant persistance.
 * Le {@code chauffeurId} peut avoir été ajusté ou laissé vide (à rattacher).
 */
public record ContraventionImportItem(
        String numeroContravention,
        @NotNull Long vehiculeId,
        Long chauffeurId,
        String codeInfraction,
        String typeInfraction,
        String lieu,
        @NotNull LocalDate dateInfraction,
        LocalTime heureInfraction,
        Integer vitesseRelevee,
        BigDecimal montant,
        String documentSourcePath
) {}
