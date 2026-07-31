package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

import java.math.BigDecimal;

public record ElementMaintenanceResponse(
        Long id,
        CatalogueElementMaintenanceResponse catalogueElement,
        String libelle,
        /** Exemplaires posés ; 1 pour les lignes d'avant la quantité. */
        Integer quantite,
        /** TOTAL de la ligne : quantité × prix unitaire. */
        BigDecimal montant,
        /** Prix d'un exemplaire, recalculé — évite au client de rediviser. */
        BigDecimal prixUnitaire,
        Long partenaireId,
        String partenaireNom
) {}
