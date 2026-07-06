package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

import java.time.LocalDate;

public record VidangeResponse(
        Long id,
        Long vehiculeId,
        LocalDate dateVidange,
        Integer kilometrageVidange,
        LocalDate dateProchaineVidange,
        Integer kilometrageProchaineVidange,
        String commentaire
) {}
