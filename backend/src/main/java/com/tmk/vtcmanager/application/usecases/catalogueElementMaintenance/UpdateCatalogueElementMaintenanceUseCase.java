package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Met à jour ce qu'un élément du catalogue porte pour tous les modèles : son
 * libellé et son type de maintenance. Prix et image se changent par modèle
 * ({@link EnregistrerTarifElementMaintenanceUseCase}). L'unicité du libellé est
 * garantie par l'index {@code uk_catalogue_elements_maintenance_libelle_ci}.
 */
@RequiredArgsConstructor
public class UpdateCatalogueElementMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;
    private final TypeMaintenanceCatalogue typeMaintenance;

    @Transactional
    public CatalogueElementMaintenance execute(Long id, String libelle, Long categorieTypeId) {
        CatalogueElementMaintenance element = repository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Élément catalogue", id));
        element.update(libelle);
        typeMaintenance.appliquer(element, categorieTypeId);
        return repository.save(element);
    }
}
