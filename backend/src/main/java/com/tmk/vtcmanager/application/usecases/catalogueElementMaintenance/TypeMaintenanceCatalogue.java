package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import lombok.RequiredArgsConstructor;

/**
 * Résout le type de maintenance auquel un élément de catalogue est réservé. Le
 * type doit être une catégorie de la sous-catégorie « Maintenances », celle que
 * le formulaire de maintenance propose : un élément rattaché à une recette ou à
 * une assurance ne serait jamais proposé. Sans type, l'élément reste commun.
 */
@RequiredArgsConstructor
public class TypeMaintenanceCatalogue {

    static final String SOUS_CATEGORIE_MAINTENANCES = "Maintenances";

    private final CategorieOperationRepository categorieOperationRepository;

    public void appliquer(CatalogueElementMaintenance element, Long categorieTypeId) {
        if (categorieTypeId == null) {
            element.affecterType(null, null);
            return;
        }
        CategorieOperation type = categorieOperationRepository
                .findBySousCategorieLibelle(SOUS_CATEGORIE_MAINTENANCES).stream()
                .filter(c -> categorieTypeId.equals(c.getId()))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException(
                        "Le type choisi n'est pas un type de maintenance."));
        element.affecterType(type.getId(), type.getLibelle());
    }
}
