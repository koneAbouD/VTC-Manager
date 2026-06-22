package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CatalogueElementMaintenanceEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CatalogueElementMaintenanceJpaRepository extends JpaRepository<CatalogueElementMaintenanceEntity, Long> {

    List<CatalogueElementMaintenanceEntity> findByActifTrueOrderByLibelleAsc();

    @Query("SELECT COUNT(e) > 0 FROM ElementMaintenanceEntity e WHERE e.catalogueElement.id = :id")
    boolean existsInElementMaintenance(@Param("id") Long id);
}
