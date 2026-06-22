package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import java.math.BigDecimal;

public record CotisationRecetteRequest(
        String nom,
        BigDecimal montant,
        Integer ordre
) {}
