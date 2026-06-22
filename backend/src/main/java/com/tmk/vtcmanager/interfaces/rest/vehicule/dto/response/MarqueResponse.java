package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

public record MarqueResponse(
        Long id,
        String nom,
        String paysOrigine,
        TypeVehiculeResponse type
) {}