package com.tmk.vtcmanager.interfaces.rest.utilisateur.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record CreateGestionnaireRequest(
        @NotBlank String username,
        @Email String email,
        @NotBlank String firstName,
        @NotBlank String lastName,
        @NotBlank @Pattern(regexp = "^\\+?[0-9\\s\\-]{6,20}$", message = "Numéro de téléphone invalide") String phone
) {}