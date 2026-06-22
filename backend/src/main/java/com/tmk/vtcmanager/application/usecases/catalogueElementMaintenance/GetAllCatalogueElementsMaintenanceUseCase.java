package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetAllCatalogueElementsMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;

    public List<CatalogueElementMaintenance> execute() {
        return repository.findAllActifs();
    }
}
