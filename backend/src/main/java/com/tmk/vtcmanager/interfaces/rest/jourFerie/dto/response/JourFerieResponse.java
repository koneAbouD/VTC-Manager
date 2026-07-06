package com.tmk.vtcmanager.interfaces.rest.jourFerie.dto.response;

import java.time.LocalDate;

public record JourFerieResponse(
        Long id,
        LocalDate date,
        String libelle,
        String type,
        Integer annee,
        String source
) {}
