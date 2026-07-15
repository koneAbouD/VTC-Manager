package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ChauffeurEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ChauffeurJpaRepository extends JpaRepository<ChauffeurEntity, Long> {

    List<ChauffeurEntity> findByStatut(ChauffeurStatus statut, Sort sort);

    Page<ChauffeurEntity> findByStatut(ChauffeurStatus statut, Pageable pageable);

    boolean existsByVehiculeId(Long vehiculeId);

    Optional<ChauffeurEntity> findByKeycloakUserId(String keycloakUserId);

    /**
     * Recherche par téléphone en normalisant le stockage (retrait des séparateurs)
     * et en acceptant la forme canonique (225…) ou locale (0…).
     */
    @org.springframework.data.jpa.repository.Query(
            value = "SELECT * FROM chauffeurs "
                  + "WHERE regexp_replace(telephone, '[^0-9]', '', 'g') IN (:canonique, :local) "
                  + "LIMIT 1",
            nativeQuery = true)
    Optional<ChauffeurEntity> findByTelephoneNormalise(
            @org.springframework.data.repository.query.Param("canonique") String canonique,
            @org.springframework.data.repository.query.Param("local") String local);
}
