package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ModeAlternance;
import com.tmk.vtcmanager.application.domain.programmeTravail.TypeProgrammeTravail;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Set;

public record ProgrammeTravailResponse(
        Long id,
        Long vehiculeId,
        Integer nombreChauffeursAutorises,
        TypeProgrammeTravail typeProgramme,
        @JsonFormat(pattern = "HH:mm") LocalTime heureDebutService,
        @JsonFormat(pattern = "HH:mm") LocalTime heureFinService,
        ModeAlternance modeAlternance,
        Integer joursAlternance,
        LocalDate dateDebutAlternance,
        Set<JourSemaine> joursAlternanceSemaine,
        boolean jourSalaireActif,
        JourSemaine jourSalaire,
        List<ProgrammeChauffeurResponse> chauffeurs
) {}
