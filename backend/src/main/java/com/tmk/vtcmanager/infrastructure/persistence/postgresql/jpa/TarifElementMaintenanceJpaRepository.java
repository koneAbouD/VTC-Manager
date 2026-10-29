package com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TarifElementMaintenanceEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TarifElementMaintenanceJpaRepository
        extends JpaRepository<TarifElementMaintenanceEntity, Long> {

    // Le modèle et sa marque viennent avec le tarif : leurs noms sont lus après
    // la requête, hors de toute session.
    String AVEC_MODELE = "SELECT t FROM TarifElementMaintenanceEntity t "
            + "LEFT JOIN FETCH t.modele m LEFT JOIN FETCH m.marque ";

    @Query(AVEC_MODELE)
    List<TarifElementMaintenanceEntity> findAllAvecModele();

    @Query(AVEC_MODELE + "WHERE t.elementId = :elementId")
    List<TarifElementMaintenanceEntity> findByElementIdAvecModele(@Param("elementId") Long elementId);

    @Query(AVEC_MODELE + "WHERE t.modeleId = :modeleId")
    List<TarifElementMaintenanceEntity> findByModeleIdAvecModele(@Param("modeleId") Long modeleId);

    @Query(AVEC_MODELE + "WHERE t.elementId = :elementId AND t.modeleId = :modeleId")
    Optional<TarifElementMaintenanceEntity> findByElementIdAndModeleIdAvecModele(
            @Param("elementId") Long elementId, @Param("modeleId") Long modeleId);

    long countByImage(String image);
}
