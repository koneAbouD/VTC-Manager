package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.VehiculeEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface VehiculeJpaRepository extends JpaRepository<VehiculeEntity, Long> {

    Optional<VehiculeEntity> findByImmatriculation(String immatriculation);

    List<VehiculeEntity> findByStatut(VehiculeStatus statut, Sort sort);

    Page<VehiculeEntity> findByStatut(VehiculeStatus statut, Pageable pageable);

    List<VehiculeEntity> findByDateProchaineMaintenanceLessThanEqual(LocalDate date);

    List<VehiculeEntity> findByConditionTravailId(Long conditionTravailId);

    long countByGroupeId(Long groupeId);
}
