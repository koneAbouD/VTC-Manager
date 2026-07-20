package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

import java.math.BigDecimal;

/** Totaux de la carte solde de l'accueil pour une période. */
public record SoldePeriodeResponse(
        BigDecimal revenus,
        BigDecimal depenses,
        BigDecimal solde
) {}
