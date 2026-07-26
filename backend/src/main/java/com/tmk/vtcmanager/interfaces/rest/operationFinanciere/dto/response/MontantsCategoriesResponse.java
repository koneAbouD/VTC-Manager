package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

/**
 * Montant total par « catégorie » de la page Opérations (buckets UI :
 * recette / cotisation / pénalité / maintenance / document), pour les filtres
 * courants <b>hors filtre catégorie</b> — alimente les info-bulles des chips.
 */
public record MontantsCategoriesResponse(
        double total,
        double recette,
        double cotisation,
        double penalite,
        double maintenance,
        double document
) {}
