package com.tmk.vtcmanager.interfaces.rest.parametre.dto;

public record ParametreResponse(
        String cle,
        String valeur,
        String libelle,
        String description
) {}
