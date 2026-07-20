package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

import java.math.BigDecimal;

public record CatalogueElementMaintenanceResponse(
        Long id,
        String libelle,
        boolean actif,
        BigDecimal montantDefaut,
        // Nom d'objet de l'image (à renvoyer tel quel lors d'une mise à jour).
        String image,
        // URL présignée temporaire pour afficher l'image (null si aucune image).
        String imageUrl
) {}
