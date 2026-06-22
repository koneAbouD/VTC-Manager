package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteCatalogueElementMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;

    @Transactional
    public void execute(Long id) {
        repository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Élément catalogue", id));
        if (repository.isReferencedByElementMaintenance(id)) {
            throw new IllegalStateException(
                    "Impossible de supprimer cet élément catalogue : il est utilisé dans des opérations de maintenance existantes.");
        }
        repository.deleteById(id);
    }
}
