package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface VehiculeRepository {

    Vehicule save(Vehicule vehicule);

    Optional<Vehicule> findById(Long id);

    Optional<Vehicule> findByImmatriculation(String immatriculation);

    List<Vehicule> findAll();

    PageResult<Vehicule> findPage(VehiculeStatus statut, int page, int size);

    List<Vehicule> findByStatut(VehiculeStatus statut);

    List<Vehicule> findByDateProchaineMaintenanceLessThanEqual(LocalDate date);

    List<Vehicule> findByConditionTravailId(Long conditionTravailId);

    void deleteById(Long id);

    long countByGroupeId(Long groupeId);
}
