package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ClotureCaisseRequest(
        /** Montant physiquement compté. */
        @NotNull @PositiveOrZero BigDecimal soldeCompte,
        /** Obligatoire si le comptage diffère du solde théorique. */
        String motifEcart,
        /** Journée comptée. Absente = aujourd'hui ; jamais future. */
        LocalDate dateCloture,
        /** Qui répond du fonds. Absent = l'utilisateur qui clôture. */
        String responsable
) {}
