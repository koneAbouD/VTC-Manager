package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.response;

import java.math.BigDecimal;
import java.util.List;

public record TresorerieSummaryResponse(
        List<CompteTresorerieResponse> comptes,
        BigDecimal totalTresorerie,
        /** Contraventions encaissées auprès des chauffeurs, non reversées à l'État. */
        BigDecimal aReverserEtat
) {}
