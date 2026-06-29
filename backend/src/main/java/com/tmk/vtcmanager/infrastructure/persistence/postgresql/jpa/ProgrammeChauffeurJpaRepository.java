package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ProgrammeChauffeurEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ProgrammeChauffeurJpaRepository
        extends JpaRepository<ProgrammeChauffeurEntity, Long> {

    List<ProgrammeChauffeurEntity> findByChauffeurId(Long chauffeurId);
}
