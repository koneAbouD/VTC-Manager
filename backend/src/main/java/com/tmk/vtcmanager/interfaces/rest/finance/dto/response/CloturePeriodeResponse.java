package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.time.LocalDateTime;

public record CloturePeriodeResponse(
        Long id,
        int annee,
        int mois,
        LocalDateTime dateCloture
) {}
