package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

import java.math.BigDecimal;

public record CotisationRecetteResponse(
        Long id,
        String nom,
        BigDecimal montant,
        Integer ordre
) {}
