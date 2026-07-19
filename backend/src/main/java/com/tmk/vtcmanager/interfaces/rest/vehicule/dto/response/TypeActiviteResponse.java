package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

public record TypeActiviteResponse(
        Long id,
        String nom,
        String description,
        boolean actif
) {}