package com.tmk.vtcmanager.interfaces.rest.auth.dto;

import jakarta.validation.constraints.NotBlank;

/** Connexion chauffeur par identifiant (téléphone) + mot de passe. */
public record ChauffeurLoginDto(
        @NotBlank(message = "L'identifiant est requis") String identifiant,
        @NotBlank(message = "Le mot de passe est requis") String motDePasse
) {}
