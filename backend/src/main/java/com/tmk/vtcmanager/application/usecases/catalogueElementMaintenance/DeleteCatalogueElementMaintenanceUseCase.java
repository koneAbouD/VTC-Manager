package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.TarifElementMaintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.TarifElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@RequiredArgsConstructor
public class DeleteCatalogueElementMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;
    private final TarifElementMaintenanceRepository tarifRepository;
    private final ImagesCatalogueMaintenance images;

    @Transactional
    public void execute(Long id) {
        repository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Élément catalogue", id));
        if (repository.isReferencedByElementMaintenance(id)) {
            throw new IllegalStateException(
                    "Impossible de supprimer cet élément catalogue : il est utilisé dans des opérations de maintenance existantes.");
        }
        // Les tarifs partent avec l'élément (ON DELETE CASCADE) ; leurs images
        // sont nettoyées ensuite, sauf si un autre élément s'en sert encore.
        List<TarifElementMaintenance> tarifs = tarifRepository.findByElementId(id);
        tarifs.forEach(t -> tarifRepository.deleteById(t.getId()));
        repository.deleteById(id);
        tarifs.stream()
                .map(TarifElementMaintenance::getImage)
                .distinct()
                .forEach(images::supprimerSiOrpheline);
    }
}
