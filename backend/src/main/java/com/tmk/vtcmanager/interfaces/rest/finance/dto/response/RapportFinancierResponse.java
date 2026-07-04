package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;
import java.util.List;

public record RapportFinancierResponse(
        BigDecimal totalRevenus,
        BigDecimal totalDepenses,
        BigDecimal variationRevenusPct,
        BigDecimal variationDepensesPct,
        String groupBy,
        List<BreakdownItemResponse> breakdownRevenus,
        List<BreakdownItemResponse> breakdownDepenses,
        List<OperationLigneResponse> listeOperations
) {}
