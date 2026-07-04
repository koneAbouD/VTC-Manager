package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;

public record MargeVehiculeResponse(
        Long vehiculeId,
        String immatriculation,
        BigDecimal produits,
        BigDecimal chargesVariables,
        BigDecimal marge
) {}
