package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.IndisponibiliteEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface IndisponibiliteJpaRepository extends JpaRepository<IndisponibiliteEntity, Long> {

    List<IndisponibiliteEntity> findByChauffeurIdOrderByDateDebutDesc(Long chauffeurId);

    List<IndisponibiliteEntity> findByStatut(IndisponibiliteStatut statut);
}
