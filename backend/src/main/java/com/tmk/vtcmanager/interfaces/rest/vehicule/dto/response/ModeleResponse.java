package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

public record ModeleResponse(
        Long id,
        String nom,
        MarqueResponse marque,
        TypeVehiculeResponse type
) {}