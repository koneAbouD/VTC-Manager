package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

public record BaliseResponse(
        Long id,
        String identifiant,
        String numeroTelephone,
        boolean actif
) {}
