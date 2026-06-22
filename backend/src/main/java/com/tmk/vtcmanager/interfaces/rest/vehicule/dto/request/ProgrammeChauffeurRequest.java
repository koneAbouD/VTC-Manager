package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record ProgrammeChauffeurRequest(
        @NotNull Long chauffeurId,
        Integer ordreAlternance,
        Integer ordreJourSalaire,
        @JsonFormat(pattern = "yyyy-MM-dd") LocalDate dateService
) {}
