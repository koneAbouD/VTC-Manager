package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.tmk.vtcmanager.application.domain.configurationRecette.FrequenceVersement;
import com.tmk.vtcmanager.application.domain.configurationRecette.ModeEncaissement;
import com.tmk.vtcmanager.application.domain.configurationRecette.TypeRecetteConfiguration;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalTime;
import java.util.List;

public record ConfigurationRecetteRequest(
        @NotNull ModeEncaissement modeEncaissement,
        @NotNull TypeRecetteConfiguration typeRecette,
        @NotNull FrequenceVersement frequenceVersement,
        @NotNull @JsonFormat(pattern = "HH:mm") LocalTime heureLimiteVersement,
        BigDecimal montantObjectifParChauffeur,
        BigDecimal montantJourSalaire,
        @Valid List<CotisationRecetteRequest> cotisations
) {}
