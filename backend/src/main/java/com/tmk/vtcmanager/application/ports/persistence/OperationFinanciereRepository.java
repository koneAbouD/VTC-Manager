package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;

import java.util.List;
import java.util.Optional;

public interface OperationFinanciereRepository {

    OperationFinanciere save(OperationFinanciere operation);

    Optional<OperationFinanciere> findById(Long id);

    List<OperationFinanciere> findByCriteres(OperationFinanciereFiltres filtres);

    PageResult<OperationFinanciere> findPageByCriteres(OperationFinanciereFiltres filtres, int page, int size);

    List<OperationFinanciere> findByChauffeurId(Long chauffeurId);

    List<OperationFinanciere> findByVehiculeId(Long vehiculeId);

    boolean existsByReference(String reference);

    void deleteById(Long id);
}
