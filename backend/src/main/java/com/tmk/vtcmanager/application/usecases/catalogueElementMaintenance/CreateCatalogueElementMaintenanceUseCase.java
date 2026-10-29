package com.tmk.vtcmanager.application.usecases.catalogueElementMaintenance;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class CreateCatalogueElementMaintenanceUseCase {

    private final CatalogueElementMaintenanceRepository repository;
    private final CibleVehiculeCatalogue cibleVehicule;
    private final TypeMaintenanceCatalogue typeMaintenance;

    @Transactional
    public CatalogueElementMaintenance execute(CatalogueElementMaintenance element) {
        element.setActif(true);
        cibleVehicule.appliquer(element, element.getMarqueId(), element.getModeleId());
        typeMaintenance.appliquer(element, element.getCategorieTypeId());
        return repository.save(element);
    }
}
