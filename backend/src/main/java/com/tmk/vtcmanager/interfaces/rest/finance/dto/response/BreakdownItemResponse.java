package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;

public record BreakdownItemResponse(
        String label,
        BigDecimal montant,
        BigDecimal pourcentage
) {}
