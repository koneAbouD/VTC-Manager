package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Met à jour le libellé d'un élément de catalogue de maintenance. L'unicité du
 * libellé est garantie par la contrainte {@code uk_catalogue_elements_maintenance_libelle}
 * (→ 409 via le gestionnaire d'exceptions global).
 */
@RequiredArgsConstructor
public class UpdateCatalogueElementMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;

    @Transactional
    public CatalogueElementMaintenance execute(Long id, String libelle) {
        CatalogueElementMaintenance element = repository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Élément catalogue", id));
        element.update(libelle);
        return repository.save(element);
    }
}
