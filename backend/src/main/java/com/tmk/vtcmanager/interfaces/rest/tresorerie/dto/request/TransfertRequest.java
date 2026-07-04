package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.time.LocalDate;

public record TransfertRequest(
        @NotNull Long compteSourceId,
        @NotNull Long compteDestinationId,
        @NotNull @Positive BigDecimal montant,
        /** Optionnel : aujourd'hui par défaut. */
        LocalDate dateTransfert,
        String commentaire
) {}
