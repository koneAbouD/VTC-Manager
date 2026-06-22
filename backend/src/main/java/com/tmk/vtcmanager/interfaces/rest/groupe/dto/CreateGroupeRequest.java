package com.tmk.vtcmanager.interfaces.rest.groupe.dto;

import jakarta.validation.constraints.NotBlank;

public record CreateGroupeRequest(
        @NotBlank String nom,
        String description,
        Long typeActiviteId,
        String gestionnaireUserId
) {}