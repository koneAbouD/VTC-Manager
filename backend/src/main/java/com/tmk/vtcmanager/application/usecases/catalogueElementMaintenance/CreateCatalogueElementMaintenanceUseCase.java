package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class CreateCatalogueElementMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;

    @Transactional
    public CatalogueElementMaintenance execute(CatalogueElementMaintenance element) {
        element.setActif(true);
        return repository.save(element);
    }
}
