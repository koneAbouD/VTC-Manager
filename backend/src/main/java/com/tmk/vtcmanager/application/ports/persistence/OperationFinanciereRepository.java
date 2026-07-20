package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.domain.operation.OperationFinanciereFiltres;
import com.tmk.vtcmanager.application.domain.operation.SoldePeriode;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface OperationFinanciereRepository {

    OperationFinanciere save(OperationFinanciere operation);

    Optional<OperationFinanciere> findById(Long id);

    List<OperationFinanciere> findByCriteres(OperationFinanciereFiltres filtres);

    /**
     * Agrège revenus / dépenses sur la période [debut, fin] (bornes incluses,
     * nullables = pas de borne), opérations annulées exclues.
     */
    SoldePeriode calculerSolde(LocalDate debut, LocalDate fin);

    PageResult<OperationFinanciere> findPageByCriteres(OperationFinanciereFiltres filtres, int page, int size);

    List<OperationFinanciere> findByChauffeurId(Long chauffeurId);

    List<OperationFinanciere> findByVehiculeId(Long vehiculeId);

    boolean existsByReference(String reference);

    void deleteById(Long id);
}
