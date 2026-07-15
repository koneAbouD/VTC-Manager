package com.tmk.vtcmanager.interfaces.rest.selfservice.dto;

/** Chauffeur sélectionnable comme remplaçant (vue légère pour le picker). */
public record RemplacantResponse(
        Long id,
        String nomComplet,
        String telephone
) {}
