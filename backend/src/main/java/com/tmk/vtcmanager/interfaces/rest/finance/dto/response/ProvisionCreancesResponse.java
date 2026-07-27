package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;

/** Détail de la dépréciation des créances, tranche par tranche. */
public record ProvisionCreancesResponse(
        BigDecimal creancesBrutes,
        BigDecimal base0a7Jours,
        BigDecimal base8a30Jours,
        BigDecimal basePlus30Jours,
        BigDecimal taux0a7Jours,
        BigDecimal taux8a30Jours,
        BigDecimal tauxPlus30Jours,
        BigDecimal provision0a7Jours,
        BigDecimal provision8a30Jours,
        BigDecimal provisionPlus30Jours,
        BigDecimal provisionTotale,
        BigDecimal creancesNettes
) {}
