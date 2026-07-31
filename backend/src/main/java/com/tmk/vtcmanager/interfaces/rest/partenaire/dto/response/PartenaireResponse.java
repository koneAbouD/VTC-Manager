package com.tmk.vtcmanager.interfaces.rest.partenaire.dto.response;

public record PartenaireResponse(
        Long id,
        String nom,
        Long typeId,
        String typeNom,
        String telephone,
        String email,
        String adresse,
        String numeroCompteContribuable,
        String commentaire,
        boolean actif
) {}
