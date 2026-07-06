package com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record ConditionTravailResponse(
        Long id,
        String nom,
        int nbChauffeurs,
        String typeProgramme,
        String heureDebutService,
        String heureFinService,
        String modeAlternance,
        Integer joursAlternance,
        LocalDate dateDebutAlternance,
        String jourSalaire,
        BigDecimal objectifRecette,
        String typeRecette,
        BigDecimal montantJourSalaire,
        boolean feriesConsideres,
        BigDecimal montantJourFerie,
        String modeEncaissement,
        String frequenceVersement,
        String jourVersement,
        String heureVersement,
        List<String> joursTravail,
        List<CotisationTemplateResponse> cotisations,
        List<PenaliteTemplateResponse> penalites
) {}
