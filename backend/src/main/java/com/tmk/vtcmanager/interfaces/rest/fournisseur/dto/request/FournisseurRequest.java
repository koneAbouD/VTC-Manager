package com.tmk.vtcmanager.interfaces.rest.fournisseur.dto.request;

import com.tmk.vtcmanager.application.domain.fournisseur.TypeFournisseur;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record FournisseurRequest(
        @NotBlank @Size(max = 150) String nom,
        @NotNull TypeFournisseur type,
        @Size(max = 30) String telephone,
        @Size(max = 150) String email,
        @Size(max = 255) String adresse,
        @Size(max = 50) String numeroCompteContribuable,
        String commentaire
) {}
