package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

public record TypeVehiculeResponse(
        Long id,
        String nom,
        String description,
        boolean actif
) {}