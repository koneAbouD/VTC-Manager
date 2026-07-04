package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;

public record CompteResultatResponse(
        int annee,
        int mois,
        String base,
        BigDecimal produitsExploitation,
        BigDecimal chargesVariables,
        BigDecimal margeSurCoutsVariables,
        BigDecimal chargesFixes,
        BigDecimal excedentBrutExploitation,
        BigDecimal amortissements,
        BigDecimal resultatGestion,
        BigDecimal pontCreances
) {}
