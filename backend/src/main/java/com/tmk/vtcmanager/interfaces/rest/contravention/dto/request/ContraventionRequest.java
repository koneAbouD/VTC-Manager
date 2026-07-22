package com.tmk.vtcmanager.interfaces.rest.contravention.dto.request;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;

public record ContraventionRequest(
        @NotNull LocalDate dateInfraction,
        String typeInfraction,
        String lieu,
        String description,
        BigDecimal montant,
        BigDecimal cotisation,
        BigDecimal montantPaye,
        LocalDate datePaiement,
        Long chauffeurId,
        @NotNull Long vehiculeId,
        // Champs propres aux contraventions de l'État (saisie manuelle possible).
        String numeroContravention,
        LocalTime heureInfraction,
        Integer vitesseRelevee,
        String codeInfraction
) {}