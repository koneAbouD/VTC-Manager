package com.tmk.vtcmanager.interfaces.rest.fournisseur.dto.response;

import com.tmk.vtcmanager.application.domain.fournisseur.TypeFournisseur;

public record FournisseurResponse(
        Long id,
        String nom,
        TypeFournisseur type,
        String telephone,
        String email,
        String adresse,
        String numeroCompteContribuable,
        String commentaire,
        boolean actif
) {}
