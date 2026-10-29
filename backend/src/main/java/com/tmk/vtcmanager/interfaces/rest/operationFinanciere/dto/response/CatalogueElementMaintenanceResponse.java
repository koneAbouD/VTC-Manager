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
        String imageUrl,
        // Marque / modèle réservés (null : élément générique, ou toute la marque).
        Long marqueId,
        String marqueNom,
        Long modeleId,
        String modeleNom,
        // Type de maintenance réservé (null : élément commun à tous les types).
        Long categorieTypeId,
        String categorieTypeLibelle
) {}
