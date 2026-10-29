package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.TarifElementMaintenance;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.TarifElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Retire un élément d'un modèle : il n'y est plus proposé. Les maintenances
 * passées gardent leurs lignes, qui pointent l'élément et non son tarif.
 */
@RequiredArgsConstructor
public class SupprimerTarifElementMaintenanceUseCase {

    private final TarifElementMaintenanceRepository tarifRepository;
    private final ImagesCatalogueMaintenance images;

    @Transactional
    public void execute(Long elementId, Long modeleId) {
        TarifElementMaintenance tarif = tarifRepository.findByElementIdAndModeleId(elementId, modeleId)
                .orElseThrow(() -> ResourceNotFoundException.of("Tarif", elementId));
        tarifRepository.deleteById(tarif.getId());
        images.supprimerSiOrpheline(tarif.getImage());
    }
}
