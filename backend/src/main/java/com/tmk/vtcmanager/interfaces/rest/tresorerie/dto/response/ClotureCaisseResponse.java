package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ClotureCaisseResponse(
        Long id,
        Long compteId,
        LocalDate dateCloture,
        BigDecimal soldeTheorique,
        BigDecimal soldeCompte,
        BigDecimal ecart,
        String motifEcart,
        Long operationId
) {}
