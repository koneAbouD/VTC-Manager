package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record BilanResponse(
        LocalDate date,
        BigDecimal tresorerie,
        /** Créances brutes. */
        BigDecimal creancesChauffeurs,
        /** Dépréciation appliquée selon l'ancienneté. */
        BigDecimal provisionCreances,
        /** Montant retenu à l'actif : brutes − provision. */
        BigDecimal creancesNettes,
        BigDecimal immobilisationsNettes,
        BigDecimal totalActif,
        BigDecimal detteEtatContraventions,
        /** Reste dû aux fournisseurs sur les factures non soldées. */
        BigDecimal dettesFournisseurs,
        BigDecimal situationNette
) {}
