package com.tmk.vtcmanager.interfaces.rest.penalite.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.time.LocalDate;

public record EncaissementPenaliteRequest(
        @NotNull @Positive BigDecimal montant,
        @NotNull String modeEncaissement,
        @NotNull LocalDate dateEncaissement,
        String reference,
        String commentaire
) {}
