package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ChauffeurEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ChauffeurJpaRepository extends JpaRepository<ChauffeurEntity, Long> {

    List<ChauffeurEntity> findByStatut(ChauffeurStatus statut, Sort sort);

    Page<ChauffeurEntity> findByStatut(ChauffeurStatus statut, Pageable pageable);

    boolean existsByVehiculeId(Long vehiculeId);
}
