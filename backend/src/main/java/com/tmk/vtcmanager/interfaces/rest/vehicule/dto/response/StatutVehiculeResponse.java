package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response;

public record StatutVehiculeResponse(
        String code,
        String libelle,
        String signification,
        String couleur,
        Integer ordre
) {}
