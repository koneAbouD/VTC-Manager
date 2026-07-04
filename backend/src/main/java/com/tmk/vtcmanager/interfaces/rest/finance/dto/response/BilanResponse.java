package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record BilanResponse(
        LocalDate date,
        BigDecimal tresorerie,
        BigDecimal creancesChauffeurs,
        BigDecimal immobilisationsNettes,
        BigDecimal totalActif,
        BigDecimal detteEtatContraventions,
        BigDecimal situationNette
) {}
