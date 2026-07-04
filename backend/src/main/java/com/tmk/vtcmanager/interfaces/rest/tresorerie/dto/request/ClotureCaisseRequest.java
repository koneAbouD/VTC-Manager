package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;

public record ClotureCaisseRequest(
        /** Montant physiquement compté. */
        @NotNull @PositiveOrZero BigDecimal soldeCompte,
        /** Obligatoire si le comptage diffère du solde théorique. */
        String motifEcart
) {}
