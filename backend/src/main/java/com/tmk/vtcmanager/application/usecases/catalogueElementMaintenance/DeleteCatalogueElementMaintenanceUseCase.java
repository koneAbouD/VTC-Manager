package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@RequiredArgsConstructor
public class DeleteCatalogueElementMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;
    private final FileStoragePort storage;

    @Transactional
    public void execute(Long id) {
        CatalogueElementMaintenance element = repository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Élément catalogue", id));
        if (repository.isReferencedByElementMaintenance(id)) {
            throw new IllegalStateException(
                    "Impossible de supprimer cet élément catalogue : il est utilisé dans des opérations de maintenance existantes.");
        }
        repository.deleteById(id);

        // Nettoyage best-effort de l'image associée (évite les orphelins).
        if (element.getImage() != null && !element.getImage().isBlank()) {
            try {
                storage.delete(element.getImage());
            } catch (Exception e) {
                log.warn("Suppression de l'image '{}' échouée : {}", element.getImage(), e.getMessage());
            }
        }
    }
}
