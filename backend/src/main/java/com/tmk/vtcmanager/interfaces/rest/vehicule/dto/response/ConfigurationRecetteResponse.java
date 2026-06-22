package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.tmk.vtcmanager.application.domain.configurationRecette.FrequenceVersement;
import com.tmk.vtcmanager.application.domain.configurationRecette.ModeEncaissement;
import com.tmk.vtcmanager.application.domain.configurationRecette.TypeRecetteConfiguration;

import java.math.BigDecimal;
import java.time.LocalTime;
import java.util.List;

public record ConfigurationRecetteResponse(
        Long id,
        Long vehiculeId,
        ModeEncaissement modeEncaissement,
        TypeRecetteConfiguration typeRecette,
        FrequenceVersement frequenceVersement,
        @JsonFormat(pattern = "HH:mm") LocalTime heureLimiteVersement,
        BigDecimal montantObjectifParChauffeur,
        BigDecimal montantJourSalaire,
        List<CotisationRecetteResponse> cotisations
) {}
