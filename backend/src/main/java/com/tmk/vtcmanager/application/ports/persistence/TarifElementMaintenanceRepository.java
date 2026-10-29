package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.operation.TarifElementMaintenance;

import java.util.List;
import java.util.Optional;

/** Tarifs des éléments du catalogue de maintenance, un par modèle de véhicule. */
public interface TarifElementMaintenanceRepository {

    TarifElementMaintenance save(TarifElementMaintenance tarif);

    List<TarifElementMaintenance> findAll();

    List<TarifElementMaintenance> findByElementId(Long elementId);

    List<TarifElementMaintenance> findByModeleId(Long modeleId);

    Optional<TarifElementMaintenance> findByElementIdAndModeleId(Long elementId, Long modeleId);

    void deleteById(Long id);

    /** Nombre de tarifs qui utilisent ce fichier image. */
    long compterParImage(String image);
}
