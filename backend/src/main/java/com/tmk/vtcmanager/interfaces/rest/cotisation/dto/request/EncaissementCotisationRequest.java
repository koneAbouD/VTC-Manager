package com.tmk.vtcmanager.interfaces.rest.cotisation.dto.request;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.time.LocalDate;

public record EncaissementCotisationRequest(
        @NotNull @Positive BigDecimal montant,
        @NotNull ModePaiement modeEncaissement,
        @NotNull LocalDate dateEncaissement,
        String reference,
        String commentaire
) {}
