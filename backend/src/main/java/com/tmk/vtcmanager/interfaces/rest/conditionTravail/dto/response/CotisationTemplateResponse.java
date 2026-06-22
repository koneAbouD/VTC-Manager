package com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.response;

import java.math.BigDecimal;

public record CotisationTemplateResponse(
        Long id,
        String nom,
        BigDecimal montant
) {}
