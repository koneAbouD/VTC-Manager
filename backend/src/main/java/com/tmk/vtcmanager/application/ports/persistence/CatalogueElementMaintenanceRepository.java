package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;

import java.util.List;
import java.util.Optional;

public interface CatalogueElementMaintenanceRepository {

    CatalogueElementMaintenance save(CatalogueElementMaintenance element);

    Optional<CatalogueElementMaintenance> findById(Long id);

    List<CatalogueElementMaintenance> findAll();

    List<CatalogueElementMaintenance> findAllActifs();

    void deleteById(Long id);

    boolean isReferencedByElementMaintenance(Long id);
}
