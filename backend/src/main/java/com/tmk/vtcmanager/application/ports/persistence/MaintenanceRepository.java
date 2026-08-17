package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface MaintenanceRepository {

    Maintenance save(Maintenance maintenance);

    Optional<Maintenance> findById(Long id);

    List<Maintenance> findAll();

    /**
     * @param recherche mot-clé libre (type de maintenance, immatriculation du
     *                  véhicule, nom du prestataire) ; ignoré s'il est vide
     */
    PageResult<Maintenance> findPageByFiltres(LocalDate dateDebut, LocalDate dateFin,
                                              MaintenanceStatus statut, Long vehiculeId,
                                              String recherche, int page, int size);

    List<Maintenance> findByVehiculeId(Long vehiculeId);

    List<Maintenance> findByStatut(MaintenanceStatus statut);

    /** Indique s'il existe au moins une maintenance dans ce statut pour le véhicule. */
    boolean existsByVehiculeIdAndStatut(Long vehiculeId, MaintenanceStatus statut);

    List<Maintenance> findByType(String type);

    List<Maintenance> findByDatePrevueLessThanEqualAndStatut(LocalDate date, MaintenanceStatus statut);

    List<Maintenance> findByFiltres(LocalDate dateDebut, LocalDate dateFin, MaintenanceStatus statut, Long vehiculeId);

    void deleteById(Long id);
}
