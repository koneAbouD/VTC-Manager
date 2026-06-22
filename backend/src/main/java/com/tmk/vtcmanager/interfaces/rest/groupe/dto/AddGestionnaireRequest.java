package com.tmk.vtcmanager.interfaces.rest.groupe.dto;

import jakarta.validation.constraints.NotBlank;

import java.time.LocalDate;

public record AddGestionnaireRequest(
        @NotBlank String userId,
        LocalDate dateDebut,
        LocalDate dateFin
) {}