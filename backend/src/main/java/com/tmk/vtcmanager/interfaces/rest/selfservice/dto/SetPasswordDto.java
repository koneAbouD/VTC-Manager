package com.tmk.vtcmanager.interfaces.rest.selfservice.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Définition/changement du mot de passe par le chauffeur connecté. */
public record SetPasswordDto(
        @NotBlank(message = "Le mot de passe est requis")
        @Size(min = 6, message = "Le mot de passe doit contenir au moins 6 caractères")
        String motDePasse
) {}
