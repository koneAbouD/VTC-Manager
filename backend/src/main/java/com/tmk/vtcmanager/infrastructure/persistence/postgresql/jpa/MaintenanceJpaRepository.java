package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MaintenanceEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface MaintenanceJpaRepository extends JpaRepository<MaintenanceEntity, Long>,
        JpaSpecificationExecutor<MaintenanceEntity> {

    /**
     * Liste filtrée : véhicule, catégorie de type et prestataire voyagent avec
     * la page — la réponse expose leur immatriculation, leur libellé et leur
     * nom. Sans ce graphe, chaque page déclenchait trois requêtes par ligne.
     */
    @Override
    @EntityGraph(attributePaths = {"vehicule", "categorieType", "partenaire"})
    Page<MaintenanceEntity> findAll(Specification<MaintenanceEntity> spec, Pageable pageable);

    List<MaintenanceEntity> findByVehiculeId(Long vehiculeId);

    List<MaintenanceEntity> findByStatut(MaintenanceStatus statut);

    boolean existsByVehiculeIdAndStatut(Long vehiculeId, MaintenanceStatus statut);

    List<MaintenanceEntity> findByType(String type);

    List<MaintenanceEntity> findByDatePrevueLessThanEqualAndStatut(LocalDate date, MaintenanceStatus statut);

    List<MaintenanceEntity> findByVehiculeIdOrderByCreatedAtDesc(Long vehiculeId);

    List<MaintenanceEntity> findByStatutOrderByCreatedAtDesc(MaintenanceStatus statut);
}
