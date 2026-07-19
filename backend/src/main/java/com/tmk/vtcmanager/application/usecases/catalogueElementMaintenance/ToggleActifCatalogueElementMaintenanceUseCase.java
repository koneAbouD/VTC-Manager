package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Active / désactive un élément de catalogue de maintenance (soft-disable).
 * Un élément inactif reste en base et référencé par l'historique, mais n'est
 * plus proposé à la saisie de nouvelles opérations de maintenance.
 */
@RequiredArgsConstructor
public class ToggleActifCatalogueElementMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;

    @Transactional
    public CatalogueElementMaintenance execute(Long id, boolean actif) {
        CatalogueElementMaintenance element = repository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Élément catalogue", id));
        element.changerActivation(actif);
        return repository.save(element);
    }
}
