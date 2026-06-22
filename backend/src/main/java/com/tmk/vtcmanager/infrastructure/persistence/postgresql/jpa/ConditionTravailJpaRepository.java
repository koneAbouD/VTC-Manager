package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ConditionTravailEntity;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface ConditionTravailJpaRepository extends JpaRepository<ConditionTravailEntity, Long> {

    @Query("SELECT v.conditionTravail FROM VehiculeEntity v WHERE v.id = :vehiculeId AND v.conditionTravail IS NOT NULL")
    Optional<ConditionTravailEntity> findByVehiculeId(@Param("vehiculeId") Long vehiculeId);
}
