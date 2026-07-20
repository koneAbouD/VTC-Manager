package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

/**
 * Éléments de maintenance <b>actifs uniquement</b>, triés par libellé — destinés
 * à la sélection (saisie d'une opération de maintenance). Le paramétrage, lui,
 * consomme la liste complète via {@link GetAllCatalogueElementsMaintenanceUseCase}.
 */
@RequiredArgsConstructor
public class GetActifsCatalogueElementsMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;

    public List<CatalogueElementMaintenance> execute() {
        return repository.findAllActifs();
    }
}
