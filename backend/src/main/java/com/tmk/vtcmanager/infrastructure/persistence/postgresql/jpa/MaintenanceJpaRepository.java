package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MaintenanceEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface MaintenanceJpaRepository extends JpaRepository<MaintenanceEntity, Long>,
        JpaSpecificationExecutor<MaintenanceEntity> {

    List<MaintenanceEntity> findByVehiculeId(Long vehiculeId);

    List<MaintenanceEntity> findByStatut(MaintenanceStatus statut);

    boolean existsByVehiculeIdAndStatut(Long vehiculeId, MaintenanceStatus statut);

    List<MaintenanceEntity> findByType(String type);

    List<MaintenanceEntity> findByDatePrevueLessThanEqualAndStatut(LocalDate date, MaintenanceStatus statut);

    List<MaintenanceEntity> findByVehiculeIdOrderByCreatedAtDesc(Long vehiculeId);

    List<MaintenanceEntity> findByStatutOrderByCreatedAtDesc(MaintenanceStatus statut);
}
