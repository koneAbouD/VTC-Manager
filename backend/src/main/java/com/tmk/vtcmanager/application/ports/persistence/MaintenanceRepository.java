package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceFiltres;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.maintenance.TotalMaintenanceParStatut;
import com.tmk.vtcmanager.application.domain.maintenance.TotalMaintenanceParType;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface MaintenanceRepository {

    Maintenance save(Maintenance maintenance);

    Optional<Maintenance> findById(Long id);

    List<Maintenance> findAll();

    /**
     * @param aujourdhui jour de référence du filtre « en retard »
     */
    PageResult<Maintenance> findPageByFiltres(MaintenanceFiltres filtres, LocalDate aujourdhui,
                                              int page, int size);

    /** Cumuls par type de maintenance, appliqués tels quels aux filtres reçus. */
    List<TotalMaintenanceParType> totauxParType(MaintenanceFiltres filtres);

    /** Cumuls par statut, appliqués tels quels aux filtres reçus. */
    List<TotalMaintenanceParStatut> totauxParStatut(MaintenanceFiltres filtres);

    long compter(MaintenanceFiltres filtres, LocalDate aujourdhui);

    List<Maintenance> findByVehiculeId(Long vehiculeId);

    List<Maintenance> findByStatut(MaintenanceStatus statut);

    /** Indique s'il existe au moins une maintenance dans ce statut pour le véhicule. */
    boolean existsByVehiculeIdAndStatut(Long vehiculeId, MaintenanceStatus statut);

    List<Maintenance> findByType(String type);

    List<Maintenance> findByDatePrevueLessThanEqualAndStatut(LocalDate date, MaintenanceStatus statut);

    List<Maintenance> findByFiltres(LocalDate dateDebut, LocalDate dateFin, MaintenanceStatus statut, Long vehiculeId);

    void deleteById(Long id);
}
