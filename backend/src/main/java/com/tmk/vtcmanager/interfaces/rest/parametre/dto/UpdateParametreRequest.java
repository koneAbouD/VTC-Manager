package com.tmk.vtcmanager.interfaces.rest.parametre.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateParametreRequest(
        @NotBlank String valeur
) {}
