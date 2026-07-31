package com.tmk.vtcmanager.interfaces.rest.partenaire.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record PartenaireRequest(
        @NotBlank @Size(max = 150) String nom,
        /** Type choisi dans le référentiel des types de partenaire. */
        @NotNull Long typeId,
        @Size(max = 30) String telephone,
        @Size(max = 150) String email,
        @Size(max = 255) String adresse,
        @Size(max = 50) String numeroCompteContribuable,
        String commentaire
) {}
