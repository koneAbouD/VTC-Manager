package com.tmk.vtcmanager.interfaces.rest.partenaire.dto.response;

public record TypePartenaireResponse(
        Long id,
        String nom,
        String description,
        boolean actif
) {}
