package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.GroupeVehiculeEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface GroupeVehiculeJpaRepository extends JpaRepository<GroupeVehiculeEntity, Long> {

    @Query("SELECT g FROM GroupeVehiculeEntity g LEFT JOIN FETCH g.typeActivite LEFT JOIN FETCH g.gestionnaire ORDER BY g.updatedAt DESC, g.createdAt DESC")
    List<GroupeVehiculeEntity> findAllWithRelations();

    @Query("SELECT g FROM GroupeVehiculeEntity g LEFT JOIN FETCH g.typeActivite LEFT JOIN FETCH g.gestionnaire WHERE g.id = :id")
    Optional<GroupeVehiculeEntity> findByIdWithRelations(@Param("id") Long id);

    boolean existsByNom(String nom);
}