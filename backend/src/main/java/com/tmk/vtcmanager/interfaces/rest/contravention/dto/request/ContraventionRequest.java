package com.tmk.vtcmanager.interfaces.rest.contravention.dto.request;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;

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
        Long vehiculeId
) {}