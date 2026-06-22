package com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.request;

import java.math.BigDecimal;

public record CotisationTemplateRequest(
        String nom,
        BigDecimal montant
) {}
