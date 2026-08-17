package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ContraventionEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ContraventionJpaRepository
        extends JpaRepository<ContraventionEntity, Long>,
                JpaSpecificationExecutor<ContraventionEntity> {

    /**
     * Liste filtrée : véhicule et chauffeur voyagent avec la page. La réponse
     * expose leur immatriculation et leur nom — sans ce graphe, chaque page
     * déclenchait deux requêtes par contravention.
     */
    @Override
    @EntityGraph(attributePaths = {"vehicule", "chauffeur"})
    Page<ContraventionEntity> findAll(Specification<ContraventionEntity> spec, Pageable pageable);

    List<ContraventionEntity> findByChauffeurId(Long chauffeurId, Sort sort);

    List<ContraventionEntity> findByVehiculeId(Long vehiculeId, Sort sort);

    List<ContraventionEntity> findByStatut(ContraventionStatus statut);

    boolean existsByNumeroContravention(String numeroContravention);

    Optional<ContraventionEntity> findByNumeroContravention(String numeroContravention);
}
