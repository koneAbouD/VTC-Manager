package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ModeleEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ModeleJpaRepository extends JpaRepository<ModeleEntity, Long> {

    Optional<ModeleEntity> findByNom(String nom);

    List<ModeleEntity> findByMarqueId(Long marqueId);

    boolean existsByNom(String nom);

    @Query("SELECT m FROM ModeleEntity m WHERE m.marque.id = :marqueId")
    List<ModeleEntity> findByMarque(@Param("marqueId") Long marqueId);
}
